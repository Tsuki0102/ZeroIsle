import { common } from '@kit.AbilityKit'
import { Database } from '../data/Database'

/**
 * 演示数据生成器
 * 用途:数据层自检 + 演示视频/现场路演时快速铺出"会生长的岛"
 * 口径:约 3 周校园低碳生活,累计减排落在绿屿(≥50kg)量级
 */
export class DemoData {
  static async generate(context: common.UIAbilityContext): Promise<number> {
    await Database.clearAll(context)
    let n: number = 0
    for (let daysAgo = 20; daysAgo >= 0; daysAgo--) {
      const dateStr: string = Database.dateBefore(daysAgo)
      // 通勤:每天 1-2 次
      const rideKm: number = Math.round((2 + Math.random() * 6) * 10) / 10
      await Database.insertRow(context, 'T01', rideKm, dateStr, '手动', '')
      n++
      if (Math.random() > 0.5) {
        const walkKm: number = Math.round((1 + Math.random() * 3) * 10) / 10
        await Database.insertRow(context, 'T02', walkKm, dateStr, '手动', '')
        n++
      }
      // 光盘:每天 1-2 餐
      await Database.insertRow(context, 'F01', 1, dateStr, '手动', '')
      n++
      if (Math.random() > 0.4) {
        await Database.insertRow(context, 'F01', 1, dateStr, '手动', '')
        n++
      }
      // 节电:约半数日子
      if (Math.random() > 0.5) {
        const kwh: number = Math.round((1 + Math.random() * 2) * 10) / 10
        await Database.insertRow(context, 'E01', kwh, dateStr, '手动', '')
        n++
      }
      // 回收:约四分之一日子
      if (Math.random() > 0.75) {
        const clothesKg: number = Math.round((0.5 + Math.random() * 1.5) * 10) / 10
        await Database.insertRow(context, 'R01', clothesKg, dateStr, '手动', '')
        n++
      }
      if (Math.random() > 0.8) {
        const bottles: number = 2 + Math.floor(Math.random() * 6)
        await Database.insertRow(context, 'R03', bottles, dateStr, '手动', '')
        n++
      }
      // 绿色习惯:约三分之一日子
      if (Math.random() > 0.67) {
        await Database.insertRow(context, 'H01', 1, dateStr, '手动', '')
        n++
      }
    }
    // 收尾:一棵树,直接冲击更高的生态值(演示用)
    await Database.insertRow(context, 'H05', 1, Database.today(), '手动', '报名参加校园植树')
    n++
    return n
  }
}
