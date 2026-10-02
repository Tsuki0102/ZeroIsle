import { common } from '@kit.AbilityKit'
import { Database, Summary, CategorySum, DailyPoint } from '../data/Database'
import { FactorLibrary } from '../data/FactorLibrary'
import { ISLAND_STAGES } from '../model/Models'

/** 一条岛灵建议 */
export class Advice {
  icon: string = '💡'
  title: string = ''
  detail: string = ''
}

/**
 * 岛灵建议:本地规则引擎(全离线)
 * 基于累计/当日数据、近 14 天逐日趋势、分类占比、连续打卡与岛屿阶段,
 * 生成个性化的低碳行动建议,对应赛题"智能服务:个性化生活建议"。
 */
export class AdvisorService {
  static async advise(ctx: common.UIAbilityContext): Promise<Advice[]> {
    const out: Advice[] = []
    const s: Summary = await Database.summary(ctx)
    if (s.count === 0) {
      const a = new Advice()
      a.icon = '🌱'
      a.title = '从第一笔记录开始'
      a.detail = '在下方输入「骑车3公里」或「午餐光盘」,岛屿就会开始生长'
      out.push(a)
      return out
    }

    const cats: CategorySum[] = await Database.categoryStats(ctx)
    const series: DailyPoint[] = await Database.dailySeries(ctx, 14)
    const streak: number = await Database.streak(ctx)
    let weekNow: number = 0
    let weekPrev: number = 0
    const d7: string = Database.dateBefore(6)
    const d14: string = Database.dateBefore(13)
    for (const d of series) {
      if (d.date >= d7) {
        weekNow += d.co2
      } else if (d.date >= d14) {
        weekPrev += d.co2
      }
    }

    // 规则1:当日空窗引导
    if (s.todayCount === 0) {
      const a = new Advice()
      a.icon = '⏰'
      a.title = '今天还没有记录'
      a.detail = '做一件 5 分钟的小事:骑行 3 公里 ≈ 减排 0.60 kg,可得 6 枚岛币'
      out.push(a)
    } else {
      const a = new Advice()
      a.icon = '✅'
      a.title = `今日已减排 ${s.todayCo2.toFixed(2)} kg`
      a.detail = '岛灵帮你记着呢,晚上看看「析」页的趋势图吧'
      out.push(a)
    }

    // 规则2:周趋势对比(近7天 vs 前7天)
    if (weekPrev > 0.5 && weekNow > 0.5) {
      const a = new Advice()
      const delta: number = weekNow - weekPrev
      if (delta >= 0) {
        a.icon = '📈'
        a.title = `本周比上周多减 ${delta.toFixed(1)} kg`
        a.detail = '节奏很好,岛灵已经把你的坚持记进岛屿年轮里'
      } else {
        a.icon = '🍂'
        a.title = `本周比上周少了 ${(-delta).toFixed(1)} kg`
        a.detail = '周末安排一次绿色出行或光盘打卡,把节奏找回来'
      }
      out.push(a)
    }

    // 规则3:分类结构单一 → 多样化建议
    let total: number = 0
    let top: CategorySum | null = null
    for (const c of cats) {
      total += c.co2
      if (top === null || c.co2 > top.co2) {
        top = c
      }
    }
    if (top !== null && total > 1 && top.co2 / total >= 0.6 && cats.length >= 2) {
      const a = new Advice()
      const pct: number = Math.round(top.co2 / total * 100)
      const second: CategorySum | null = cats.filter((c: CategorySum) => c.categoryId !== top?.categoryId)
        .sort((x: CategorySum, y: CategorySum) => y.co2 - x.co2)[0] ?? null
      a.icon = '🧭'
      a.title = `你的减排集中在「${FactorLibrary.categoryName(top.categoryId)}」(${pct}%)`
      if (second !== null) {
        a.detail = `试试每周补 3 次「${FactorLibrary.categoryName(second.categoryId)}」,让碳画像更均衡`
      } else {
        a.detail = '试试加入光盘打卡或节电行动,让五维碳画像更均衡'
      }
      out.push(a)
    }

    // 规则4:连续打卡里程碑
    if (streak >= 3) {
      const a = new Advice()
      a.icon = '🔥'
      a.title = `连续打卡 ${streak} 天`
      a.detail = streak >= 7 ? '「七日之约」徽章已到手,下一个目标是 21 天' : '离「七日之约」徽章只差几步,别断签哦'
      out.push(a)
    }

    // 规则5:下一阶段冲刺(按近7天日均速估算达成天数)
    let next = ISLAND_STAGES[ISLAND_STAGES.length - 1]
    for (let i = 0; i < ISLAND_STAGES.length - 1; i++) {
      if (s.totalCo2 >= ISLAND_STAGES[i].thresholdKg) {
        next = ISLAND_STAGES[i + 1]
      }
    }
    if (s.totalCo2 < next.thresholdKg) {
      const gap: number = next.thresholdKg - s.totalCo2
      const speed: number = weekNow > 0 ? weekNow / 7 : 0
      const a = new Advice()
      a.icon = '🏝️'
      a.title = `距「${next.name}」还差 ${gap.toFixed(1)} kg`
      a.detail = speed > 0.05
        ? `按最近节奏约 ${Math.ceil(gap / speed)} 天可达,每天一小步就够`
        : '从一笔小记录开始,岛屿就会向你靠近'
      out.push(a)
    }
    return out
  }
}
