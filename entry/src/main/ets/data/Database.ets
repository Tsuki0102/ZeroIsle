import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { POINTS_PER_KG, PLATFORM_POINTS_PER_KG } from '../model/Models'
import { FactorLibrary } from './FactorLibrary'
import { BehaviorFactor } from '../model/Models'

/** 汇总统计 */
export class Summary {
  count: number = 0
  totalCo2: number = 0
  totalPoints: number = 0
  todayCo2: number = 0
  todayCount: number = 0
}

/** 单日聚合(图表用) */
export class DailyPoint {
  date: string = ''
  co2: number = 0
  points: number = 0
  cnt: number = 0
}

/** 分类聚合 */
export class CategorySum {
  categoryId: string = ''
  co2: number = 0
  cnt: number = 0
}

/** 期间聚合(报表汇总:按年-月) */
export class PeriodSum {
  /** 期间键:年-月(如 2026-09) */
  key: string = ''
  co2: number = 0
  cnt: number = 0
}

/** 平台权益凭证(碳普惠兑换所得) */
export class Voucher {
  id: number = 0
  title: string = ''
  code: string = ''
  cost: number = 0
  createdAt: number = 0
}

/** 城市碳普惠平台碳积分账户(与岛币独立核算) */
export class PlatformAccount {
  /** 已累计获得的碳积分 */
  earned: number = 0
  /** 已兑换消耗的碳积分 */
  spent: number = 0
  /** 已上报的减排量(kg) */
  uploadedCo2: number = 0
  /** 可用碳积分 = earned - spent */
  balance: number = 0
  /** 待上报减排量(kg) = 本机累计 - 已上报 */
  pending: number = 0
}

/** 历史记录条目 */
export class HistoryItem {
  id: number = 0
  factorId: string = ''
  name: string = ''
  icon: string = ''
  amount: number = 0
  unit: string = ''
  co2Kg: number = 0
  points: number = 0
  date: string = ''
  source: string = ''
  note: string = ''
}

/**
 * 零屿本地数据层(RelationalStore / SQLite,全离线)
 */
export class Database {
  private static rdb: relationalStore.RdbStore | null = null

  private static readonly CREATE_RECORD: string = `CREATE TABLE IF NOT EXISTS behavior_record (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    factor_id TEXT NOT NULL,
    category_id TEXT NOT NULL,
    scene TEXT NOT NULL,
    amount REAL NOT NULL,
    unit TEXT NOT NULL,
    co2_kg REAL NOT NULL,
    points INTEGER NOT NULL,
    record_date TEXT NOT NULL,
    note TEXT DEFAULT '',
    source TEXT NOT NULL DEFAULT '手动',
    created_at INTEGER NOT NULL)`
  private static readonly CREATE_TASK_LOG: string = `CREATE TABLE IF NOT EXISTS task_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    finish_date TEXT NOT NULL,
    created_at INTEGER NOT NULL)`
  private static readonly CREATE_EXCHANGE: string = `CREATE TABLE IF NOT EXISTS exchange_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item TEXT NOT NULL,
    cost INTEGER NOT NULL,
    created_at INTEGER NOT NULL)`
  private static readonly CREATE_KV: string = `CREATE TABLE IF NOT EXISTS kv_store (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL)`
  private static readonly CREATE_REWARD: string = `CREATE TABLE IF NOT EXISTS reward_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    period_key TEXT NOT NULL,
    points INTEGER NOT NULL,
    created_at INTEGER NOT NULL)`
  private static readonly CREATE_VOUCHER: string = `CREATE TABLE IF NOT EXISTS voucher_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    code TEXT NOT NULL,
    cost INTEGER NOT NULL,
    created_at INTEGER NOT NULL)`

  /** 获取(懒初始化)数据库 */
  static async get(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    if (Database.rdb !== null) {
      return Database.rdb
    }
    const config: relationalStore.StoreConfig = {
      name: 'zeroisle.db',
      securityLevel: relationalStore.SecurityLevel.S1
    }
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config)
    await store.executeSql(Database.CREATE_RECORD)
    await store.executeSql(Database.CREATE_TASK_LOG)
    await store.executeSql(Database.CREATE_EXCHANGE)
    await store.executeSql(Database.CREATE_REWARD)
    await store.executeSql(Database.CREATE_VOUCHER)
    await store.executeSql(Database.CREATE_KV)
    // 常用查询列索引(日期聚合/分类聚合/来源汇总)
    await store.executeSql('CREATE INDEX IF NOT EXISTS idx_record_date ON behavior_record(record_date)')
    await store.executeSql('CREATE INDEX IF NOT EXISTS idx_record_category ON behavior_record(category_id)')
    await store.executeSql('CREATE INDEX IF NOT EXISTS idx_record_source ON behavior_record(source)')
    Database.rdb = store
    return store
  }

  // ---------- 日期工具 ----------

  static fmtDate(d: Date): string {
    const m: string = (d.getMonth() + 1) < 10 ? '0' + (d.getMonth() + 1) : '' + (d.getMonth() + 1)
    const day: string = d.getDate() < 10 ? '0' + d.getDate() : '' + d.getDate()
    return `${d.getFullYear()}-${m}-${day}`
  }

  static today(): string {
    return Database.fmtDate(new Date())
  }

  static dateBefore(daysAgo: number): string {
    const d = new Date()
    d.setDate(d.getDate() - daysAgo)
    return Database.fmtDate(d)
  }

  /** 本自然周周一日期(周任务周期口径:周一 0 点刷新) */
  static weekMonday(): string {
    const d = new Date()
    const dow: number = d.getDay()
    d.setDate(d.getDate() - (dow === 0 ? 6 : dow - 1))
    return Database.fmtDate(d)
  }

  /** 判定 id 是否为因子 id(否则视为分类 id) */
  private static isFactorId(id: string): boolean {
    for (const f of FactorLibrary.factors) {
      if (f.id === id) {
        return true
      }
    }
    return false
  }

  // ---------- 写入 ----------

  /** 插入一条行为记录,返回新行 id(按当天日期) */
  static async insertRecord(context: common.UIAbilityContext, factorId: string,
    amount: number, source: string, note: string): Promise<number> {
    return Database.insertRow(context, factorId, amount, Database.today(), source, note)
  }

  /** 插入指定日期的记录(演示数据/补录用) */
  static async insertRow(context: common.UIAbilityContext, factorId: string,
    amount: number, dateStr: string, source: string, note: string): Promise<number> {
    if (!FactorLibrary.has(factorId)) {
      throw new Error(`invalid factor_id: ${factorId}`)
    }
    const store = await Database.get(context)
    const f: BehaviorFactor = FactorLibrary.byId(factorId)
    const co2: number = amount * f.factor
    const points: number = Math.round(co2 * POINTS_PER_KG)
    const bucket: relationalStore.ValuesBucket = {
      'factor_id': f.id,
      'category_id': f.categoryId,
      'scene': f.scene,
      'amount': amount,
      'unit': f.unit,
      'co2_kg': co2,
      'points': points,
      'record_date': dateStr,
      'note': note,
      'source': source,
      'created_at': Date.now()
    }
    return store.insert('behavior_record', bucket)
  }

  static async deleteRecord(context: common.UIAbilityContext, id: number): Promise<void> {
    const store = await Database.get(context)
    const p = new relationalStore.RdbPredicates('behavior_record')
    p.equalTo('id', id)
    await store.delete(p)
  }

  /**
   * 清空行为记录与岛屿进度(行为/任务/兑换/奖励/券包五张表),
   * KV 只清进度与账务类键,保留设置与身份类键(LLM Key、昵称、收藏、持证人姓名等),
   * 与「清空数据」文案口径一致,避免误删用户配置。
   */
  static async clearAll(context: common.UIAbilityContext): Promise<void> {
    const store = await Database.get(context)
    await store.delete(new relationalStore.RdbPredicates('behavior_record'))
    await store.delete(new relationalStore.RdbPredicates('reward_log'))
    await store.delete(new relationalStore.RdbPredicates('exchange_log'))
    await store.delete(new relationalStore.RdbPredicates('task_log'))
    await store.delete(new relationalStore.RdbPredicates('voucher_log'))
    const keep: Set<string> = new Set<string>([
      'device_uuid', 'my_nickname', 'guided',
      'agent_llm_on', 'agent_llm_key', 'agent_tts',
      'lab_fav', 'profile_name'
    ])
    const p = new relationalStore.RdbPredicates('kv_store')
    const rs: relationalStore.ResultSet = await store.query(p, ['key'])
    const doomed: string[] = []
    while (rs.goToNextRow()) {
      const k: string = rs.getString(rs.getColumnIndex('key'))
      if (!keep.has(k)) {
        doomed.push(k)
      }
    }
    rs.close()
    for (const k of doomed) {
      await store.executeSql('DELETE FROM kv_store WHERE key = ?', [k])
    }
  }

  // ---------- 聚合查询 ----------

  static async summary(context: common.UIAbilityContext): Promise<Summary> {
    const store = await Database.get(context)
    const s = new Summary()

    let rs: relationalStore.ResultSet = await store.query(
      new relationalStore.RdbPredicates('behavior_record'),
      ['COUNT(*) AS cnt', 'SUM(co2_kg) AS co2', 'SUM(points) AS pts'])
    if (rs.goToFirstRow()) {
      console.info(`[ZeroIsleDB] rowCols cnt=${rs.getColumnIndex('cnt')} co2=${rs.getColumnIndex('co2')} pts=${rs.getColumnIndex('pts')}`)
      s.count = rs.getDouble(rs.getColumnIndex('cnt'))
      s.totalCo2 = rs.getDouble(rs.getColumnIndex('co2'))
      s.totalPoints = rs.getDouble(rs.getColumnIndex('pts'))
      console.info(`[ZeroIsleDB] total cnt=${s.count} co2=${s.totalCo2} pts=${s.totalPoints}`)
    } else {
      console.info('[ZeroIsleDB] total query: NO ROW')
    }
    rs.close()

    // 叠加任务奖励岛币
    s.totalPoints += await Database.rewardSum(context)

    const p = new relationalStore.RdbPredicates('behavior_record')
    p.equalTo('record_date', Database.today())
    rs = await store.query(p, ['COUNT(*) AS cnt', 'SUM(co2_kg) AS co2'])
    if (rs.goToFirstRow()) {
      s.todayCount = rs.getDouble(rs.getColumnIndex('cnt'))
      s.todayCo2 = rs.getDouble(rs.getColumnIndex('co2'))
      console.info(`[ZeroIsleDB] today=${Database.today()} cnt=${s.todayCount} co2=${s.todayCo2}`)
    } else {
      console.info('[ZeroIsleDB] today query: NO ROW')
    }
    rs.close()
    return s
  }

  /** 构造带时段 / 分类筛选的查询谓词(空串表示不限) */
  private static rangePredicates(startDate: string, endDate: string, categoryId: string): relationalStore.RdbPredicates {
    const p = new relationalStore.RdbPredicates('behavior_record')
    if (startDate !== '') {
      p.greaterThanOrEqualTo('record_date', startDate)
    }
    if (endDate !== '') {
      p.lessThanOrEqualTo('record_date', endDate)
    }
    if (categoryId !== '') {
      p.equalTo('category_id', categoryId)
    }
    return p
  }

  /** 按录入来源汇总(碳知实验室等模块展示自身战果) */
  static async summaryBySource(context: common.UIAbilityContext, source: string): Promise<Summary> {
    const store = await Database.get(context)
    const p = new relationalStore.RdbPredicates('behavior_record')
    p.equalTo('source', source)
    const rs: relationalStore.ResultSet = await store.query(p,
      ['COUNT(*) AS cnt', 'SUM(co2_kg) AS co2', 'SUM(points) AS pts'])
    const s = new Summary()
    if (rs.goToFirstRow()) {
      s.count = rs.getDouble(rs.getColumnIndex('cnt'))
      s.totalCo2 = rs.getDouble(rs.getColumnIndex('co2'))
      s.totalPoints = rs.getDouble(rs.getColumnIndex('pts'))
    }
    rs.close()
    return s
  }

  /** 最近 N 天逐日聚合(缺失日期由调用方补零;可按分类过滤) */
  static async dailySeries(context: common.UIAbilityContext, days: number,
    categoryId: string = ''): Promise<DailyPoint[]> {
    return Database.dailyRange(context, Database.dateBefore(days - 1), '', categoryId)
  }

  /** 指定时段逐日聚合(空串表示不限;可按分类过滤,报表汇总复用) */
  static async dailyRange(context: common.UIAbilityContext, startDate: string, endDate: string,
    categoryId: string = ''): Promise<DailyPoint[]> {
    const store = await Database.get(context)
    const p = Database.rangePredicates(startDate, endDate, categoryId)
    p.groupBy(['record_date'])
    p.orderByAsc('record_date')
    const rs: relationalStore.ResultSet = await store.query(p,
      ['record_date', 'SUM(co2_kg) AS co2', 'SUM(points) AS pts', 'COUNT(*) AS cnt'])
    const list: DailyPoint[] = []
    while (rs.goToNextRow()) {
      const dp = new DailyPoint()
      dp.date = rs.getString(rs.getColumnIndex('record_date'))
      dp.co2 = rs.getDouble(rs.getColumnIndex('co2'))
      dp.points = rs.getLong(rs.getColumnIndex('pts'))
      dp.cnt = rs.getLong(rs.getColumnIndex('cnt'))
      list.push(dp)
    }
    rs.close()
    return list
  }

  /** 分类聚合(可按时段过滤——看板「分类查询」随日/周/月/年联动) */
  static async categoryStats(context: common.UIAbilityContext,
    startDate: string = '', endDate: string = ''): Promise<CategorySum[]> {
    const store = await Database.get(context)
    const p = Database.rangePredicates(startDate, endDate, '')
    p.groupBy(['category_id'])
    const rs: relationalStore.ResultSet = await store.query(p,
      ['category_id', 'SUM(co2_kg) AS co2', 'COUNT(*) AS cnt'])
    const list: CategorySum[] = []
    while (rs.goToNextRow()) {
      const c = new CategorySum()
      c.categoryId = rs.getString(rs.getColumnIndex('category_id'))
      c.co2 = rs.getDouble(rs.getColumnIndex('co2'))
      c.cnt = rs.getLong(rs.getColumnIndex('cnt'))
      list.push(c)
    }
    rs.close()
    return list
  }

  /** 按「年-月」聚合(报表月度汇总块用) */
  static async monthlySeries(context: common.UIAbilityContext,
    startDate: string, endDate: string): Promise<PeriodSum[]> {
    const daily: DailyPoint[] = await Database.dailyRange(context, startDate, endDate)
    const map: Map<string, PeriodSum> = new Map()
    const order: string[] = []
    for (const d of daily) {
      const parts: string[] = d.date.split('-')
      if (parts.length < 2) {
        continue
      }
      const key: string = `${parts[0]}-${parts[1]}`
      if (!map.has(key)) {
        const ps = new PeriodSum()
        ps.key = key
        map.set(key, ps)
        order.push(key)
      }
      const cur: PeriodSum = map.get(key) as PeriodSum
      cur.co2 += d.co2
      cur.cnt += d.cnt
    }
    const list: PeriodSum[] = []
    for (const k of order) {
      list.push(map.get(k) as PeriodSum)
    }
    return list
  }

  /** 筛选结果的合计(条数 / 减排 / 岛币),用于明细页汇总条 */
  static async filterSummary(context: common.UIAbilityContext,
    startDate: string, endDate: string, categoryId: string): Promise<Summary> {
    const store = await Database.get(context)
    const p = Database.rangePredicates(startDate, endDate, categoryId)
    const rs: relationalStore.ResultSet = await store.query(p,
      ['COUNT(*) AS cnt', 'SUM(co2_kg) AS co2', 'SUM(points) AS pts'])
    const s = new Summary()
    if (rs.goToFirstRow()) {
      s.count = rs.getDouble(rs.getColumnIndex('cnt'))
      s.totalCo2 = rs.getDouble(rs.getColumnIndex('co2'))
      s.totalPoints = rs.getDouble(rs.getColumnIndex('pts'))
    }
    rs.close()
    return s
  }

  private static readonly HISTORY_COLS: string[] = [
    'id', 'factor_id', 'amount', 'unit', 'co2_kg', 'points', 'record_date', 'source', 'note']

  /** 结果集当前行 → 明细条目(history / historyFilter 共用) */
  private static mapHistory(rs: relationalStore.ResultSet): HistoryItem {
    const h = new HistoryItem()
    h.id = rs.getLong(rs.getColumnIndex('id'))
    h.factorId = rs.getString(rs.getColumnIndex('factor_id'))
    h.amount = rs.getDouble(rs.getColumnIndex('amount'))
    h.unit = rs.getString(rs.getColumnIndex('unit'))
    h.co2Kg = rs.getDouble(rs.getColumnIndex('co2_kg'))
    h.points = rs.getLong(rs.getColumnIndex('points'))
    h.date = rs.getString(rs.getColumnIndex('record_date'))
    h.source = rs.getString(rs.getColumnIndex('source'))
    h.note = rs.getString(rs.getColumnIndex('note'))
    h.name = FactorLibrary.nameOf(h.factorId)
    h.icon = FactorLibrary.categoryIcon(FactorLibrary.categoryOf(h.factorId))
    return h
  }

  /** 历史记录分页查询(E5:导出走分页流式,避免大账本一次性进内存) */
  static async history(context: common.UIAbilityContext, limit: number, offset: number = 0): Promise<HistoryItem[]> {
    return Database.historyFilter(context, '', '', '', limit, offset)
  }

  /** 明细查询(时段 + 分类筛选,分页;日期倒序) */
  static async historyFilter(context: common.UIAbilityContext, startDate: string, endDate: string,
    categoryId: string, limit: number, offset: number = 0): Promise<HistoryItem[]> {
    const store = await Database.get(context)
    const p = Database.rangePredicates(startDate, endDate, categoryId)
    p.limitAs(limit)
    p.offsetAs(offset)
    p.orderByDesc('record_date')
    p.orderByDesc('id')
    const rs: relationalStore.ResultSet = await store.query(p, Database.HISTORY_COLS)
    const list: HistoryItem[] = []
    while (rs.goToNextRow()) {
      list.push(Database.mapHistory(rs))
    }
    rs.close()
    return list
  }

  /** 连续打卡天数:从今天(或昨天)往前数有记录的连续天数 */
  static async streak(context: common.UIAbilityContext): Promise<number> {
    const store = await Database.get(context)
    const p = new relationalStore.RdbPredicates('behavior_record')
    p.distinct()
    p.orderByDesc('record_date')
    const rs: relationalStore.ResultSet = await store.query(p, ['record_date'])
    const set: Set<string> = new Set()
    while (rs.goToNextRow()) {
      set.add(rs.getString(rs.getColumnIndex('record_date')))
    }
    rs.close()
    if (set.size === 0) {
      return 0
    }
    let cursor = new Date()
    if (!set.has(Database.fmtDate(cursor))) {
      cursor.setDate(cursor.getDate() - 1)
      if (!set.has(Database.fmtDate(cursor))) {
        return 0
      }
    }
    let n: number = 0
    while (set.has(Database.fmtDate(cursor))) {
      n++
      cursor.setDate(cursor.getDate() - 1)
    }
    console.info(`[ZeroIsleDB] streak set=${set.size} result=${n} appToday=${Database.today()}`)
    return n
  }

  // ---------- 通用 KV 存储(周榜舍友数据等)----------

  static async kvSet(context: common.UIAbilityContext, key: string, value: string): Promise<void> {
    const store = await Database.get(context)
    await store.executeSql('INSERT OR REPLACE INTO kv_store (key, value) VALUES (?, ?)', [key, value])
  }

  static async kvGet(context: common.UIAbilityContext, key: string, fallback: string): Promise<string> {
    const store = await Database.get(context)
    const p = new relationalStore.RdbPredicates('kv_store')
    p.equalTo('key', key)
    const rs: relationalStore.ResultSet = await store.query(p, ['value'])
    let v: string = fallback
    if (rs.goToFirstRow()) {
      v = rs.getString(rs.getColumnIndex('value'))
    }
    rs.close()
    return v
  }

  /** 本机设备标识(首次生成后持久化):数据包导入时据此判定"是否自己的包" */
  static async getDeviceId(context: common.UIAbilityContext): Promise<string> {
    let id: string = await Database.kvGet(context, 'device_uuid', '')
    if (id === '') {
      id = util.generateRandomUUID(false)
      await Database.kvSet(context, 'device_uuid', id)
    }
    return id
  }

  /** 本机昵称(家庭积分包/周榜数据包的导出署名与榜单展示) */
  static async getNickname(context: common.UIAbilityContext): Promise<string> {
    const v: string = await Database.kvGet(context, 'my_nickname', '')
    const t: string = v.trim()
    return t === '' ? '我' : t
  }

  /** 已有记录的"日期|因子|数量"键集(备份导入去重用) */
  static async existingRecordKeys(context: common.UIAbilityContext): Promise<Set<string>> {
    const store = await Database.get(context)
    const rs: relationalStore.ResultSet = await store.query(
      new relationalStore.RdbPredicates('behavior_record'),
      ['record_date', 'factor_id', 'amount'])
    const set: Set<string> = new Set()
    while (rs.goToNextRow()) {
      set.add(`${rs.getString(rs.getColumnIndex('record_date'))}|${rs.getString(rs.getColumnIndex('factor_id'))}|${rs.getDouble(rs.getColumnIndex('amount'))}`)
    }
    rs.close()
    return set
  }

  // ---------- 激励系统:任务奖励 / 兑换 ----------

  /** 任务奖励岛币累计 */
  static async rewardSum(context: common.UIAbilityContext): Promise<number> {
    const store = await Database.get(context)
    const rs: relationalStore.ResultSet = await store.query(
      new relationalStore.RdbPredicates('reward_log'), ['SUM(points) AS pts'])
    let v: number = 0
    if (rs.goToFirstRow()) {
      v = rs.getDouble(rs.getColumnIndex('pts'))
    }
    rs.close()
    return v
  }

  /** 兑换消耗岛币累计 */
  static async spentSum(context: common.UIAbilityContext): Promise<number> {
    const store = await Database.get(context)
    const rs: relationalStore.ResultSet = await store.query(
      new relationalStore.RdbPredicates('exchange_log'), ['SUM(cost) AS cost'])
    let v: number = 0
    if (rs.goToFirstRow()) {
      v = rs.getDouble(rs.getColumnIndex('cost'))
    }
    rs.close()
    return v
  }

  /**
   * 任务进度判定
   * check 格式:类型:参数:目标
   * 参数既可为因子 id(如 F01/T01)也可为分类 id(如 travel/energy),自动适配查询列
   * today_count:F01 → 今日某行为条数;today_sum:T01 → 今日某行为数量和
   * week_count:recycle → 本周(自然周,周一 0 点起)某分类条数;week_sum:energy → 本周某分类数量和
   */
  static async taskProgress(context: common.UIAbilityContext, check: string): Promise<number> {
    const store = await Database.get(context)
    const parts: string[] = check.split(':')
    const type: string = parts[0]
    const arg: string = parts.length > 1 ? parts[1] : ''
    const col: string = Database.isFactorId(arg) ? 'factor_id' : 'category_id'
    const p = new relationalStore.RdbPredicates('behavior_record')
    let cols: string[] = ['COUNT(*) AS v']
    if (type === 'today_count') {
      p.equalTo('record_date', Database.today())
      p.equalTo(col, arg)
    } else if (type === 'today_sum') {
      p.equalTo('record_date', Database.today())
      p.equalTo(col, arg)
      cols = ['SUM(amount) AS v']
    } else if (type === 'week_count') {
      p.greaterThanOrEqualTo('record_date', Database.weekMonday())
      p.equalTo(col, arg)
    } else if (type === 'week_sum') {
      p.greaterThanOrEqualTo('record_date', Database.weekMonday())
      p.equalTo(col, arg)
      cols = ['SUM(amount) AS v']
    } else {
      return 0
    }
    const rs: relationalStore.ResultSet = await store.query(p, cols)
    let v: number = 0
    if (rs.goToFirstRow()) {
      v = rs.getDouble(rs.getColumnIndex('v'))
    }
    rs.close()
    return v
  }

  /** 该任务在该周期是否已领取 */
  static async hasClaimed(context: common.UIAbilityContext, taskId: string, periodKey: string): Promise<boolean> {
    const store = await Database.get(context)
    const p = new relationalStore.RdbPredicates('reward_log')
    p.equalTo('task_id', taskId)
    p.equalTo('period_key', periodKey)
    const rs: relationalStore.ResultSet = await store.query(p, ['id'])
    const found: boolean = rs.goToFirstRow()
    rs.close()
    return found
  }

  /** 领取任务奖励 */
  static async claimReward(context: common.UIAbilityContext, taskId: string,
    points: number, periodKey: string): Promise<void> {
    const store = await Database.get(context)
    const bucket: relationalStore.ValuesBucket = {
      'task_id': taskId,
      'period_key': periodKey,
      'points': points,
      'created_at': Date.now()
    }
    await store.insert('reward_log', bucket)
  }

  /** 岛币兑换(记消耗流水) */
  static async exchange(context: common.UIAbilityContext, itemName: string, cost: number): Promise<void> {
    const store = await Database.get(context)
    const bucket: relationalStore.ValuesBucket = {
      'item': itemName,
      'cost': cost,
      'created_at': Date.now()
    }
    await store.insert('exchange_log', bucket)
  }

  // ---------- 平台碳积分账户(与岛币分账)----------

  /** 读取平台碳积分账户(与岛币独立:1 kgCO₂e = 1 碳积分,上报后计入) */
  static async platformAccount(context: common.UIAbilityContext, totalCo2: number): Promise<PlatformAccount> {
    const a = new PlatformAccount()
    a.earned = Number(await Database.kvGet(context, 'platform_earned', '0'))
    a.spent = Number(await Database.kvGet(context, 'platform_spent', '0'))
    a.uploadedCo2 = Number(await Database.kvGet(context, 'platform_uploaded', '0'))
    a.balance = a.earned - a.spent
    const pending: number = totalCo2 - a.uploadedCo2
    a.pending = pending > 0 ? pending : 0
    return a
  }

  /** 上报新增减排量 → 折算为平台碳积分,返回本次新增积分 */
  static async platformUpload(context: common.UIAbilityContext, totalCo2: number): Promise<number> {
    const a: PlatformAccount = await Database.platformAccount(context, totalCo2)
    const gain: number = Math.floor(a.pending * PLATFORM_POINTS_PER_KG)
    await Database.kvSet(context, 'platform_earned', `${a.earned + gain}`)
    await Database.kvSet(context, 'platform_uploaded', `${totalCo2}`)
    return gain
  }

  /** 兑换平台权益:扣减碳积分并落一条权益凭证;积分不足返回 false */
  static async platformRedeem(context: common.UIAbilityContext, title: string, code: string,
    cost: number, totalCo2: number): Promise<boolean> {
    const a: PlatformAccount = await Database.platformAccount(context, totalCo2)
    if (a.balance < cost) {
      return false
    }
    await Database.kvSet(context, 'platform_spent', `${a.spent + cost}`)
    await Database.addVoucher(context, title, code, cost)
    return true
  }

  // ---------- 权益凭证(券包)----------

  /** 落一条权益凭证 */
  static async addVoucher(context: common.UIAbilityContext, title: string, code: string, cost: number): Promise<void> {
    const store = await Database.get(context)
    const bucket: relationalStore.ValuesBucket = {
      'title': title,
      'code': code,
      'cost': cost,
      'created_at': Date.now()
    }
    await store.insert('voucher_log', bucket)
  }

  /** 券包列表(按兑换时间倒序) */
  static async vouchers(context: common.UIAbilityContext, limit: number = 50): Promise<Voucher[]> {
    const store = await Database.get(context)
    const p = new relationalStore.RdbPredicates('voucher_log')
    p.limitAs(limit)
    p.orderByDesc('created_at')
    const rs: relationalStore.ResultSet = await store.query(p,
      ['id', 'title', 'code', 'cost', 'created_at'])
    const list: Voucher[] = []
    while (rs.goToNextRow()) {
      const v = new Voucher()
      v.id = rs.getLong(rs.getColumnIndex('id'))
      v.title = rs.getString(rs.getColumnIndex('title'))
      v.code = rs.getString(rs.getColumnIndex('code'))
      v.cost = rs.getLong(rs.getColumnIndex('cost'))
      v.createdAt = rs.getLong(rs.getColumnIndex('created_at'))
      list.push(v)
    }
    rs.close()
    return list
  }
}
