import { common } from '@kit.AbilityKit'
import { emitter } from '@kit.BasicServicesKit'
import { Database, Summary, CategorySum, DailyPoint } from '../data/Database'
import { FactorLibrary } from '../data/FactorLibrary'
import { ISLAND_STAGES } from '../model/Models'
import { DAILY_TASKS, WEEK_TASKS, SHOP_ITEMS } from '../model/GameConfig'
import { SemanticParser, ParseResult } from './SemanticParser'
import { AdvisorService, Advice } from './AdvisorService'
import { LlmService, AgentIntent } from './LlmService'
import { ChartPoint } from '../components/Charts'
import { EVT_DATA_CHANGED } from '../common/Common'

/** 一条对话消息:role='agent'|'user';chips 为建议追问;card 为富卡片(趋势图/任务进度等) */
export class AgentMessage {
  role: string = 'agent'
  text: string = ''
  chips: string[] = []
  card: AgentCard | null = null
  /** 回答引擎:true=LLM 智能理解,false=本地规则 */
  viaLlm: boolean = false
}

/** 富卡片负载 */
export class AgentCard {
  /** none / trend / tasks */
  kind: string = 'none'
  points: ChartPoint[] = []
  tasks: AgentTaskBrief[] = []
}

/** 任务进度摘要(卡片用) */
export class AgentTaskBrief {
  name: string = ''
  value: number = 0
  goal: number = 1
  unit: string = ''
  done: boolean = false
}

/** 跨轮次会话状态(由页面持有并传入,服务保持无副作用) */
export class AgentSession {
  /** 待确认删除的记录 id(-1=无),删除等敏感操作需二次确认 */
  pendingDeleteId: number = -1
  pendingDeleteText: string = ''
}

/**
 * 岛灵 Agent:对话式编排层(端侧规则意图 + 工具调用,全离线可用)
 *
 * 工具清单:
 *  - 记录:SemanticParser(中文数字/时间归一)→ insertRecord / insertRow(日期补录),source='岛灵'
 *  - 改账:history 定位最近一笔 → 二次确认 → deleteRecord(会话级 pending 状态)
 *  - 查询:summary / dailySeries / dailyRange / categoryStats / streak / spentSum / taskProgress
 *  - 建议:AdvisorService.advise;任务/商城目录来自 GameConfig
 *
 * LLM 扩展点:接入端侧/云侧大模型时,只需在 reply() 入口前置适配器,
 * 将自由文本转成结构化意图后仍复用同一套工具,页面与数据链路零改动。
 */
export class AgentService {
  private static readonly CHIPS_HOME: string[] =
    ['记录:骑车3公里', '本周减排多少?', '今日简报', '给我一个建议']

  private static readonly HELP_TEXT: string =
    '我是岛灵,你的碳账本管家🧚\n' +
    '· 记录:「骑车3公里」「记两次光盘」「昨天骑车2公里」\n' +
    '· 查询:「本周减排多少」「任务进度」「分类占比」「岛币余额」\n' +
    '· 改账:「把刚才那笔删了」 · 报告:「看看周报」'

  /** 对话主入口:意图路由 → 工具调用 → 组织回复 */
  static async reply(ctx: common.UIAbilityContext, input: string,
    session: AgentSession): Promise<AgentMessage> {
    const text: string = input.trim()
    if (text.length === 0) {
      return AgentService.plain('跟我说点什么吧~', AgentService.CHIPS_HOME)
    }
    // ① 待确认的删除操作:确认/取消优先处理;其他输入视为放弃确认并继续正常路由
    if (session.pendingDeleteId >= 0) {
      if (AgentService.hasAny(text, ['确认', '确定', '删', '对', '是', '嗯', '好'])) {
        return AgentService.confirmDelete(ctx, session)
      }
      if (AgentService.hasAny(text, ['取消', '不', '算了', '先不', '保留'])) {
        session.pendingDeleteId = -1
        session.pendingDeleteText = ''
        return AgentService.plain('好,已保留这笔记录~', ['给我一个建议', '本周减排多少?'])
      }
      session.pendingDeleteId = -1
      session.pendingDeleteText = ''
    }
    // ② LLM 智能增强:开启且有 Key 时优先用大模型理解意图,
    //    解析为结构化意图后仍走同一套工具;任何失败自动降级本地规则
    if (await LlmService.enabled(ctx)) {
      const intent: AgentIntent | null = await LlmService.classify(ctx, text)
      if (intent !== null) {
        return await AgentService.runIntent(ctx, intent, session)
      }
    }
    // ③ 查询类优先识别,避免「骑车能减多少碳」被误当成一笔记录
    const q: AgentMessage | null = await AgentService.routeQuery(ctx, text)
    if (q !== null) {
      return q
    }
    // ③ 改账(删除/撤销)
    if (AgentService.hasAny(text, ['删除', '删掉', '删了', '撤销', '撤回', '不算了', '去掉'])) {
      return AgentService.routeDelete(ctx, session)
    }
    // ④ 记录类
    const r: AgentMessage | null = await AgentService.routeRecord(ctx, text)
    if (r !== null) {
      return r
    }
    // ⑤ 建议 / 任务 / 商城 / 周报 / 简报 / 兜底
    if (AgentService.hasAny(text, ['建议', '推荐', '怎么办', '怎么减', '如何', '支招'])) {
      return AgentService.routeAdvice(ctx)
    }
    if (AgentService.hasAny(text, ['任务', '进度', '做完了吗'])) {
      return AgentService.queryTasks(ctx)
    }
    if (AgentService.hasAny(text, ['商城', '兑换', '能换什么', '换什么'])) {
      return AgentService.queryShop()
    }
    if (AgentService.hasAny(text, ['周报', '报告', '总结'])) {
      return AgentService.queryReport(ctx)
    }
    if (AgentService.hasAny(text, ['简报', '播报', '今日概况'])) {
      return AgentService.dailyBriefing(ctx)
    }
    if (AgentService.hasAny(text, ['排行', '第几', '榜单'])) {
      return AgentService.plain('家庭/好友周榜在「我的 → 周榜」里查看,数据经碳普惠模拟接口同步~', AgentService.CHIPS_HOME)
    }
    return AgentService.plain(AgentService.HELP_TEXT, AgentService.CHIPS_HOME)
  }

  /** 执行 LLM 解析出的结构化意图(与本地规则共用同一套工具) */
  private static async runIntent(ctx: common.UIAbilityContext, intent: AgentIntent,
    session: AgentSession): Promise<AgentMessage> {
    let m: AgentMessage
    if (intent.action === 'record') {
      const r: AgentMessage | null = await AgentService.routeRecord(ctx, intent.normalized, intent.daysAgo)
      m = r !== null ? r : AgentService.plain('没认出具体行为,试试:「骑车3公里」「光盘」', AgentService.CHIPS_HOME)
    } else if (intent.action === 'query_week') {
      m = await AgentService.queryWeek(ctx, intent.normalized !== '' ? intent.normalized : '本周')
    } else if (intent.action === 'query_month') {
      m = await AgentService.queryMonth(ctx)
    } else if (intent.action === 'query_today') {
      m = await AgentService.queryToday(ctx)
    } else if (intent.action === 'query_total') {
      m = await AgentService.queryTotal(ctx)
    } else if (intent.action === 'query_coins') {
      m = await AgentService.queryCoins(ctx)
    } else if (intent.action === 'query_cats') {
      m = await AgentService.queryCats(ctx)
    } else if (intent.action === 'query_tasks') {
      m = await AgentService.queryTasks(ctx)
    } else if (intent.action === 'query_shop') {
      m = AgentService.queryShop()
    } else if (intent.action === 'query_report') {
      m = await AgentService.queryReport(ctx)
    } else if (intent.action === 'briefing') {
      m = await AgentService.dailyBriefing(ctx)
    } else if (intent.action === 'advice') {
      m = await AgentService.routeAdvice(ctx)
    } else if (intent.action === 'delete') {
      m = await AgentService.routeDelete(ctx, session)
    } else {
      m = AgentService.plain(AgentService.HELP_TEXT, AgentService.CHIPS_HOME)
    }
    m.viaLlm = true
    return m
  }

  // ---------- 意图:待确认删除 ----------

  private static async confirmDelete(ctx: common.UIAbilityContext,
    session: AgentSession): Promise<AgentMessage> {
    const id: number = session.pendingDeleteId
    const desc: string = session.pendingDeleteText
    session.pendingDeleteId = -1
    session.pendingDeleteText = ''
    if (id < 0) {
      return AgentService.plain('没有待删除的记录~', AgentService.CHIPS_HOME)
    }
    await Database.deleteRecord(ctx, id)
    emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
    const s: Summary = await Database.summary(ctx)
    return AgentService.plain(`已删除「${desc}」\n当前累计 ${s.totalCo2.toFixed(1)} kg · 岛币 ${s.totalPoints} 分`,
      ['给我一个建议', '本周减排多少?'])
  }

  private static async routeDelete(ctx: common.UIAbilityContext,
    session: AgentSession): Promise<AgentMessage> {
    const list = await Database.history(ctx, 1)
    if (list.length === 0) {
      return AgentService.plain('还没有可删除的记录~', AgentService.CHIPS_HOME)
    }
    const h = list[0]
    const desc: string = `${h.name} ×${h.amount}${h.unit}(${h.date} · ${h.co2Kg.toFixed(2)} kg)`
    session.pendingDeleteId = h.id
    session.pendingDeleteText = desc
    return AgentService.plain(`要删除最近一笔「${desc}」吗?\n回复「确认」删除,「取消」保留`,
      ['确认', '取消'])
  }

  // ---------- 意图:查询 ----------

  private static readonly QUERY_WORDS: string[] =
    ['多少', '几', '怎么样', '趋势', '排行', '统计', '报告', '汇总', '查', '看看', '占比', '余额', '情况', '进度']
  private static readonly CARBON_WORDS: string[] =
    ['减排', '碳', '岛币', '积分', '记录', '打卡', '分类', '生态', '岛']

  private static isQuery(text: string): boolean {
    return AgentService.hasAny(text, AgentService.QUERY_WORDS) &&
      AgentService.hasAny(text, AgentService.CARBON_WORDS)
  }

  private static async routeQuery(ctx: common.UIAbilityContext, text: string): Promise<AgentMessage | null> {
    if (!AgentService.isQuery(text)) {
      return null
    }
    if (AgentService.hasAny(text, ['岛币', '积分', '余额'])) {
      return AgentService.queryCoins(ctx)
    }
    if (AgentService.hasAny(text, ['分类', '占比', '哪类', '结构'])) {
      return AgentService.queryCats(ctx)
    }
    if (AgentService.hasAny(text, ['任务'])) {
      return AgentService.queryTasks(ctx)
    }
    if (AgentService.hasAny(text, ['本周', '这周', '近一周', '一周'])) {
      return AgentService.queryWeek(ctx, text)
    }
    if (AgentService.hasAny(text, ['本月', '这个月', '近30', '三十天', '30天'])) {
      return AgentService.queryMonth(ctx)
    }
    if (AgentService.hasAny(text, ['今天', '今日'])) {
      return AgentService.queryToday(ctx)
    }
    if (AgentService.hasAny(text, ['累计', '一共', '总共', '总体', '阶段', '岛屿', '绿屿'])) {
      return AgentService.queryTotal(ctx)
    }
    // 泛化提问(如「减排多少」):给一份紧凑概览
    return AgentService.queryOverview(ctx)
  }

  private static async queryToday(ctx: common.UIAbilityContext): Promise<AgentMessage> {
    const s: Summary = await Database.summary(ctx)
    let t: string = `今天已减排 ${s.todayCo2.toFixed(2)} kg,共 ${s.todayCount} 笔记录`
    t += s.todayCount === 0
      ? '\n做一件 5 分钟的小事就很棒,比如「骑车3公里」~'
      : '\n岛灵帮你记着呢,晚上去「析」页看看趋势吧'
    return AgentService.plain(t, ['本周减排多少?', '给我一个建议'])
  }

  /** 周查询:含「本周/这周」按自然周(周一起)统计,其余为近 7 天滚动口径 */
  private static async queryWeek(ctx: common.UIAbilityContext, text: string): Promise<AgentMessage> {
    const natural: boolean = text.includes('本周') || text.includes('这周')
    let now: number = 0
    let prev: number = 0
    let label: string = ''
    if (natural) {
      const monday: string = Database.weekMonday()
      const series: DailyPoint[] = await Database.dailyRange(ctx, monday, '', '')
      for (const d of series) {
        now += d.co2
      }
      label = `本周(自 ${monday.slice(5)})`
      const dow: number = new Date().getDay()
      const prevStart: string = Database.dateBefore((dow === 0 ? 6 : dow - 1) + 7)
      const prevEnd: string = Database.dateBefore(dow === 0 ? 7 : dow)
      const prevSeries: DailyPoint[] = await Database.dailyRange(ctx, prevStart, prevEnd, '')
      for (const d of prevSeries) {
        prev += d.co2
      }
    } else {
      const series: DailyPoint[] = await Database.dailySeries(ctx, 14)
      const d7: string = Database.dateBefore(6)
      const d14: string = Database.dateBefore(13)
      for (const d of series) {
        if (d.date >= d7) {
          now += d.co2
        } else if (d.date >= d14) {
          prev += d.co2
        }
      }
      label = '近 7 天'
    }
    let t: string = `${label}共减排 ${now.toFixed(1)} kg`
    if (prev > 0.5 && now > 0.5) {
      const delta: number = now - prev
      t += delta >= 0
        ? `,比上一周期多减 ${delta.toFixed(1)} kg,节奏很好 👏`
        : `,比上一周期少了 ${(-delta).toFixed(1)} kg,周末补一次绿色出行吧`
    } else {
      t += ',继续保持每天一笔小记录~'
    }
    return AgentService.withCard(t, ['分类占比如何?', '给我一个建议'], await AgentService.trendCard(ctx, 7))
  }

  private static async queryMonth(ctx: common.UIAbilityContext): Promise<AgentMessage> {
    const n: Date = new Date()
    const mstr: string = (n.getMonth() + 1) < 10 ? '0' + (n.getMonth() + 1) : '' + (n.getMonth() + 1)
    const monthStart: string = `${n.getFullYear()}-${mstr}-01`
    const series: DailyPoint[] = await Database.dailyRange(ctx, monthStart, '', '')
    let sum: number = 0
    let cnt: number = 0
    for (const d of series) {
      sum += d.co2
      cnt += d.cnt
    }
    return AgentService.withCard(
      `本月(${monthStart} 起)累计减排 ${sum.toFixed(1)} kg,共 ${cnt} 笔记录`,
      ['本周减排多少?', '分类占比如何?'], await AgentService.trendCard(ctx, 30))
  }

  private static async queryTotal(ctx: common.UIAbilityContext): Promise<AgentMessage> {
    const s: Summary = await Database.summary(ctx)
    const streak: number = await Database.streak(ctx)
    let next = ISLAND_STAGES[ISLAND_STAGES.length - 1]
    for (let i = 0; i < ISLAND_STAGES.length - 1; i++) {
      if (s.totalCo2 >= ISLAND_STAGES[i].thresholdKg) {
        next = ISLAND_STAGES[i + 1]
      }
    }
    let t: string = `累计减排 ${s.totalCo2.toFixed(1)} kg · ${s.count} 笔 · 岛币 ${s.totalPoints} 分\n连续打卡 ${streak} 天`
    if (s.totalCo2 < next.thresholdKg) {
      t += `\n距「${next.name}」还差 ${(next.thresholdKg - s.totalCo2).toFixed(1)} kg`
    } else {
      t += '\n岛屿已是最繁茂的模样,了不起!'
    }
    return AgentService.plain(t, ['分类占比如何?', '给我一个建议'])
  }

  private static async queryOverview(ctx: common.UIAbilityContext): Promise<AgentMessage> {
    const s: Summary = await Database.summary(ctx)
    const series: DailyPoint[] = await Database.dailySeries(ctx, 7)
    let week: number = 0
    for (const d of series) {
      week += d.co2
    }
    return AgentService.plain(
      `今日 ${s.todayCo2.toFixed(2)} kg · 近 7 天 ${week.toFixed(1)} kg · 累计 ${s.totalCo2.toFixed(1)} kg\n岛币可在「营」页商城兑换徽章与证书`,
      ['本周减排多少?', '我的岛币余额'])
  }

  private static async queryCats(ctx: common.UIAbilityContext): Promise<AgentMessage> {
    const cats: CategorySum[] = await Database.categoryStats(ctx, Database.dateBefore(29))
    if (cats.length === 0) {
      return AgentService.plain('近 30 天还没有记录,先记一笔吧~', AgentService.CHIPS_HOME)
    }
    const sorted: CategorySum[] = cats.slice().sort((x: CategorySum, y: CategorySum) => y.co2 - x.co2)
    let total: number = 0
    for (const c of sorted) {
      total += c.co2
    }
    const lines: string[] = []
    for (let i = 0; i < sorted.length && i < 3; i++) {
      const pct: number = total > 0 ? Math.round(sorted[i].co2 / total * 100) : 0
      lines.push(`${i + 1}. ${FactorLibrary.categoryName(sorted[i].categoryId)} ${sorted[i].co2.toFixed(1)} kg(${pct}%)`)
    }
    return AgentService.plain(`近 30 天分类结构:\n${lines.join('\n')}`, ['给我一个建议', '本周减排多少?'])
  }

  private static async queryCoins(ctx: common.UIAbilityContext): Promise<AgentMessage> {
    // 可用岛币口径与首页一致:行为累计积分(summary.totalPoints) - 商城已消费(spentSum);
    // rewardSum 是任务奖励流水表,不含行为积分,勿混用
    const s: Summary = await Database.summary(ctx)
    const spent: number = await Database.spentSum(ctx)
    const available: number = s.totalPoints - spent
    return AgentService.plain(
      `累计获得 ${s.totalPoints} 分岛币,已消费 ${spent} 分,可用 ${available} 分\n去「营」页商城可以兑换徽章与证书`,
      ['能换什么?', '给我一个建议'])
  }

  // ---------- 意图:任务 / 商城 / 周报 / 简报 ----------

  private static async briefTasks(ctx: common.UIAbilityContext): Promise<AgentTaskBrief[]> {
    const out: AgentTaskBrief[] = []
    for (const def of DAILY_TASKS) {
      const p: number = await Database.taskProgress(ctx, def.check)
      const b = new AgentTaskBrief()
      b.name = `[今日] ${def.name}`
      b.value = Math.min(p, def.goal)
      b.goal = def.goal
      b.unit = def.unit
      b.done = p >= def.goal
      out.push(b)
    }
    for (const def of WEEK_TASKS) {
      const p: number = await Database.taskProgress(ctx, def.check)
      const b = new AgentTaskBrief()
      b.name = `[本周] ${def.name}`
      b.value = Math.min(p, def.goal)
      b.goal = def.goal
      b.unit = def.unit
      b.done = p >= def.goal
      out.push(b)
    }
    return out
  }

  private static async queryTasks(ctx: common.UIAbilityContext): Promise<AgentMessage> {
    const tasks: AgentTaskBrief[] = await AgentService.briefTasks(ctx)
    let done: number = 0
    let undone: AgentTaskBrief | null = null
    for (const b of tasks) {
      if (b.done) {
        done++
      } else if (undone === null) {
        undone = b
      }
    }
    let t: string = `任务完成度:${done}/${tasks.length}`
    if (undone !== null) {
      t += `\n下一项:「${undone.name}」还差 ${(undone.goal - undone.value).toFixed(0)}${undone.unit},去「营」页领取奖励`
    } else {
      t += '\n全部完成!记得去「营」页领奖励~'
    }
    const card = new AgentCard()
    card.kind = 'tasks'
    card.tasks = tasks
    return AgentService.withCard(t, ['我的岛币余额', '能换什么?'], card)
  }

  private static queryShop(): AgentMessage {
    const lines: string[] = []
    for (const it of SHOP_ITEMS) {
      lines.push(`${it.name} · ${it.cost} 币 —— ${it.desc}`)
    }
    return AgentService.plain(`岛币商城可兑换:\n${lines.join('\n')}\n\n在「营」页滑动到商城区即可兑换`,
      ['我的岛币余额', '给我一个建议'])
  }

  private static async queryReport(ctx: common.UIAbilityContext): Promise<AgentMessage> {
    const series: DailyPoint[] = await Database.dailySeries(ctx, 14)
    const d7: string = Database.dateBefore(6)
    const d14: string = Database.dateBefore(13)
    let now: number = 0
    let prev: number = 0
    for (const d of series) {
      if (d.date >= d7) {
        now += d.co2
      } else if (d.date >= d14) {
        prev += d.co2
      }
    }
    const s: Summary = await Database.summary(ctx)
    const streak: number = await Database.streak(ctx)
    const cats: CategorySum[] = await Database.categoryStats(ctx, Database.dateBefore(29))
    const sorted: CategorySum[] = cats.slice().sort((x: CategorySum, y: CategorySum) => y.co2 - x.co2)
    const top: string = sorted.length > 0
      ? `${FactorLibrary.categoryName(sorted[0].categoryId)}(${sorted[0].co2.toFixed(1)} kg)`
      : '暂无'
    const advices: Advice[] = await AdvisorService.advise(ctx)
    const tip: string = advices.length > 0 ? `${advices[0].icon} ${advices[0].detail}` : '保持记录,持续成长'
    const t: string =
      `📋 你的低碳周报\n` +
      `· 近 7 天减排 ${now.toFixed(1)} kg(上期 ${prev.toFixed(1)} kg)\n` +
      `· 主力分类:${top}\n` +
      `· 连续打卡 ${streak} 天 · 累计 ${s.totalCo2.toFixed(1)} kg · 岛币 ${s.totalPoints} 分\n` +
      `· 小贴士:${tip}`
    return AgentService.withCard(t, ['任务进度', '给我一个建议'], await AgentService.trendCard(ctx, 7))
  }

  /** 每日简报:今天做了什么 + 断签预警 + 冲刺进度 + 任务速览 */
  private static async dailyBriefing(ctx: common.UIAbilityContext): Promise<AgentMessage> {
    const s: Summary = await Database.summary(ctx)
    const streak: number = await Database.streak(ctx)
    const hour: number = new Date().getHours()
    const lines: string[] = []
    if (s.todayCount > 0) {
      lines.push(`· 今天已减排 ${s.todayCo2.toFixed(2)} kg(${s.todayCount} 笔)`)
    } else if (streak > 0 && hour >= 18) {
      lines.push(`· ⚠️ 连续打卡 ${streak} 天,今晚记一笔就不断签!`)
    } else {
      lines.push('· 今天还没有记录,从一件小事开始~')
    }
    let next = ISLAND_STAGES[ISLAND_STAGES.length - 1]
    for (let i = 0; i < ISLAND_STAGES.length - 1; i++) {
      if (s.totalCo2 >= ISLAND_STAGES[i].thresholdKg) {
        next = ISLAND_STAGES[i + 1]
      }
    }
    if (s.totalCo2 < next.thresholdKg) {
      lines.push(`· 距「${next.name}」还差 ${(next.thresholdKg - s.totalCo2).toFixed(1)} kg`)
    }
    const tasks: AgentTaskBrief[] = await AgentService.briefTasks(ctx)
    let undone: number = 0
    for (const b of tasks) {
      if (!b.done) {
        undone++
      }
    }
    lines.push(`· 今日+本周任务还剩 ${undone} 项未完成`)
    const card = new AgentCard()
    card.kind = 'tasks'
    card.tasks = tasks
    return AgentService.withCard(`🌅 今日简报\n${lines.join('\n')}`, ['查看任务进度', '记录:骑车3公里'], card)
  }

  // ---------- 意图:记录(含否定守卫 / 日期补录) ----------

  private static async routeRecord(ctx: common.UIAbilityContext, text: string,
    daysAgoParam: number | null = null): Promise<AgentMessage | null> {
    const pr: ParseResult = SemanticParser.parse(text)
    if (pr.items.length === 0) {
      // 有明确记录意图但没解析出行为 → 引导话术
      if (AgentService.hasAny(text, ['记录', '记一下', '记一笔', '记上'])) {
        return AgentService.plain('没认出具体行为,试试:「骑车3公里」「光盘」「节水」', AgentService.CHIPS_HOME)
      }
      return null
    }
    // 疑问句不当成记录
    if (/[?？]$|[吗呢]([吧嘛])?$|有没有|是不是/.test(text)) {
      return AgentService.plain(
        `听起来你是在问「${pr.items[0].name}」~\n如果是想记录,直接说「${pr.items[0].name}${pr.items[0].amount}${pr.items[0].unit}」就行`,
        AgentService.CHIPS_HOME)
    }
    // 否定守卫:表达"没做/不想做"时绝不写账本
    if (AgentService.hasAny(text, ['讨厌', '不想', '别', '懒得', '没有', '没做', '没记', '没'])) {
      return AgentService.plain(
        '听起来这次没有做~需要记录时,直接说行为和数量就行,例如「骑车3公里」',
        AgentService.CHIPS_HOME)
    }
    // 日期补录:昨天/前天/大前天/N天前/上周X → 写入对应日期(LLM 路径直接传入)
    const daysAgo: number | null = daysAgoParam !== null ? daysAgoParam : AgentService.datePhraseDays(text)
    let ok: number = 0
    for (const it of pr.items) {
      if (daysAgo !== null && daysAgo > 0) {
        await Database.insertRow(ctx, it.factorId, it.amount, Database.dateBefore(daysAgo), '岛灵', '岛灵对话补录')
      } else {
        await Database.insertRecord(ctx, it.factorId, it.amount, '岛灵', '岛灵对话记录')
      }
      ok++
    }
    emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
    const s: Summary = await Database.summary(ctx)
    const when: string = daysAgo !== null && daysAgo > 0 ? `补录 ${Database.dateBefore(daysAgo)}` : ''
    const lines: string[] = []
    for (const it of pr.items) {
      lines.push(`${it.icon} ${it.name} ×${it.amount}${it.unit} → 减排 ${it.co2Kg.toFixed(2)} kg / +${it.points} 币`)
    }
    let t: string = `已记下 ${pr.items.length} 笔${when !== '' ? '(' + when + ')' : ''}:\n${lines.join('\n')}\n累计 ${s.totalCo2.toFixed(1)} kg · 岛币 ${s.totalPoints} 分`
    if (pr.unmatched.length > 0) {
      t += `\n(「${pr.unmatched.join('」「')}」没认出来,未记入)`
    }
    return AgentService.plain(t, ['本周减排多少?', '给我一个建议'])
  }

  /** 解析日期表述为"几天前";无法识别返回 null */
  private static datePhraseDays(text: string): number | null {
    if (text.includes('大前天')) {
      return 3
    }
    if (text.includes('前天')) {
      return 2
    }
    if (text.includes('昨天')) {
      return 1
    }
    const m: RegExpMatchArray | null = text.match(/(\d+)\s*天前/)
    if (m !== null) {
      const v: number = parseInt(m[1])
      if (!isNaN(v) && v > 0 && v <= 60) {
        return v
      }
    }
    const wd: RegExpMatchArray | null = text.match(/上周([一二三四五六日天])/)
    if (wd !== null) {
      const names: string = '一二三四五六日'
      let idx: number = names.indexOf(wd[1])
      if (wd[1] === '天') {
        idx = 6
      }
      const dow: number = new Date().getDay()
      const lastMondayOffset: number = (dow === 0 ? 6 : dow - 1) + 7
      return Math.max(1, lastMondayOffset - idx)
    }
    return null
  }

  // ---------- 意图:建议 ----------

  private static async routeAdvice(ctx: common.UIAbilityContext): Promise<AgentMessage> {
    const list: Advice[] = await AdvisorService.advise(ctx)
    if (list.length === 0) {
      return AgentService.plain('暂时没有特别建议,保持记录就好~', AgentService.CHIPS_HOME)
    }
    const parts: string[] = []
    for (let i = 0; i < list.length && i < 2; i++) {
      parts.push(`${list[i].icon} ${list[i].title}\n${list[i].detail}`)
    }
    return AgentService.plain(parts.join('\n\n'), ['本周减排多少?', '记录:骑车3公里'])
  }

  // ---------- 工具 ----------

  private static hasAny(text: string, words: string[]): boolean {
    for (const w of words) {
      if (text.includes(w)) {
        return true
      }
    }
    return false
  }

  private static plain(text: string, chips: string[]): AgentMessage {
    const m = new AgentMessage()
    m.text = text
    m.chips = chips
    return m
  }

  private static withCard(text: string, chips: string[], card: AgentCard): AgentMessage {
    const m = new AgentMessage()
    m.text = text
    m.chips = chips
    m.card = card
    return m
  }

  /** 近 N 天趋势卡(卡片内的迷你折线数据) */
  private static async trendCard(ctx: common.UIAbilityContext, days: number): Promise<AgentCard> {
    const card = new AgentCard()
    card.kind = 'trend'
    const series: DailyPoint[] = await Database.dailySeries(ctx, days)
    for (const d of series) {
      const p = new ChartPoint()
      const parts: string[] = d.date.split('-')
      p.label = `${Number(parts[1])}.${Number(parts[2])}`
      p.value = d.co2
      card.points.push(p)
    }
    return card
  }
}
