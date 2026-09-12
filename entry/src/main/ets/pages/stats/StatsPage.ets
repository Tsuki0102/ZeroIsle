import { common } from '@kit.AbilityKit'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { EVT_DATA_CHANGED } from '../../common/Common'
import { Database, Summary, DailyPoint, CategorySum } from '../../data/Database'
import { FactorLibrary } from '../../data/FactorLibrary'
import { ChartPoint, PieSlice, TrendChart, PieChart, RadarChart, catColor } from '../../components/Charts'

/** 看板页「析」:趋势图 + 分类占比 + 碳画像雷达 + 等价物换算 */
@Component
export struct StatsPage {
  @State period: string = '日'
  @State totalCo2: number = 0
  @State todayCo2: number = 0
  @State totalCount: number = 0
  @State totalPoints: number = 0
  @State trend: ChartPoint[] = []
  @State trendMode: string = 'line'
  @State slices: PieSlice[] = []
  @State radarValues: number[] = [0, 0, 0, 0, 0]
  @State pieTotal: number = 0
  private periods: string[] = ['日', '周', '月', '年']

  aboutToAppear(): void {
    emitter.on({ eventId: EVT_DATA_CHANGED }, () => {
      this.loadAll()
    })
    this.loadAll()
  }

  private async loadAll(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const s: Summary = await Database.summary(ctx)
    this.totalCo2 = s.totalCo2
    this.todayCo2 = s.todayCo2
    this.totalCount = s.count
    this.totalPoints = s.totalPoints
    await this.loadCharts(ctx)
  }

  private async loadCharts(ctx: common.UIAbilityContext): Promise<void> {
    // 日=近7日折线;周=近4周柱;月=近6月柱;年=按年柱
    let days: number = 7
    let groupMode: string = 'day'
    if (this.period === '周') {
      days = 28
      groupMode = 'week'
    } else if (this.period === '月') {
      days = 180
      groupMode = 'month'
    } else if (this.period === '年') {
      days = 1000
      groupMode = 'year'
    }
    this.trendMode = this.period === '日' ? 'line' : 'bar'
    const daily: DailyPoint[] = await Database.dailySeries(ctx, days)
    const map: Map<string, number> = new Map()
    for (const d of daily) {
      map.set(d.date, d.co2)
    }
    const today = new Date()
    const trend: ChartPoint[] = []
    if (groupMode === 'day') {
      for (let i = days - 1; i >= 0; i--) {
        const dstr: string = Database.dateBefore(i)
        const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() - i)
        const cp = new ChartPoint()
        cp.label = `${d.getMonth() + 1}.${d.getDate()}`
        cp.value = map.get(dstr) ?? 0
        trend.push(cp)
      }
    } else {
      const buckets: Map<string, number> = new Map()
      const order: string[] = []
      for (const d of daily) {
        const parts: string[] = d.date.split('-')
        const dt = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
        const daysAgo: number = Math.round((today.getTime() - dt.getTime()) / 86400000)
        let key: string = ''
        if (groupMode === 'week') {
          const bi: number = Math.floor(daysAgo / 7)
          const start: string = Database.dateBefore(bi * 7 + 6)
          const sp: string[] = start.split('-')
          key = `${Number(sp[1])}.${Number(sp[2])}`
        } else if (groupMode === 'month') {
          key = `${Number(parts[1])}月`
        } else {
          key = parts[0]
        }
        if (!buckets.has(key)) {
          buckets.set(key, 0)
          order.push(key)
        }
        buckets.set(key, (buckets.get(key) ?? 0) + d.co2)
      }
      const sorted: string[] = []
      if (groupMode === 'week') {
        for (const k of order) {
          sorted.unshift(k)
        }
      } else {
        for (const k of order) {
          sorted.push(k)
        }
      }
      for (const k of sorted) {
        const cp = new ChartPoint()
        cp.label = k
        cp.value = buckets.get(k) ?? 0
        trend.push(cp)
      }
    }
    this.trend = trend

    // 分类占比 + 雷达
    const cats: CategorySum[] = await Database.categoryStats(ctx)
    const slices: PieSlice[] = []
    let pieSum: number = 0
    for (const c of cats) {
      const sl = new PieSlice()
      sl.label = FactorLibrary.categoryName(c.categoryId)
      sl.value = c.co2
      sl.color = catColor(c.categoryId)
      sl.icon = FactorLibrary.categoryIcon(c.categoryId)
      slices.push(sl)
      pieSum += c.co2
    }
    this.slices = slices
    this.pieTotal = pieSum
    const vals: number[] = []
    let maxCat: number = 0.0001
    const byCat: Map<string, number> = new Map()
    for (const c of cats) {
      byCat.set(c.categoryId, c.co2)
      if (c.co2 > maxCat) {
        maxCat = c.co2
      }
    }
    const ids: string[] = ['travel', 'energy', 'food', 'recycle', 'habit']
    for (const id of ids) {
      vals.push((byCat.get(id) ?? 0) / maxCat)
    }
    this.radarValues = vals
  }

  build() {
    Column() {
      // 标题
      Column() {
        Text('碳足迹看板').fontSize(22).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
        Text('看见每一次选择累积出的改变').fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      // 概览四卡(数值内联读取 @State,保证刷新)
      Row({ space: 8 }) {
        Column() {
          Text(this.totalCo2.toFixed(2)).fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
          Text('累计减排(kg)').fontSize(9).fontColor(ZeroTheme.textSub).margin({ top: 3 })
        }
        .layoutWeight(1)
        .padding({ top: 10, bottom: 10 })
        .backgroundColor(ZeroTheme.cardBg)
        .borderRadius(ZeroTheme.radiusM)
        Column() {
          Text(this.todayCo2.toFixed(2)).fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
          Text('今日减排(kg)').fontSize(9).fontColor(ZeroTheme.textSub).margin({ top: 3 })
        }
        .layoutWeight(1)
        .padding({ top: 10, bottom: 10 })
        .backgroundColor(ZeroTheme.cardBg)
        .borderRadius(ZeroTheme.radiusM)
        Column() {
          Text(`${this.totalCount}`).fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
          Text('记录次数').fontSize(9).fontColor(ZeroTheme.textSub).margin({ top: 3 })
        }
        .layoutWeight(1)
        .padding({ top: 10, bottom: 10 })
        .backgroundColor(ZeroTheme.cardBg)
        .borderRadius(ZeroTheme.radiusM)
        Column() {
          Text(`${this.totalPoints}`).fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
          Text('获得岛币').fontSize(9).fontColor(ZeroTheme.textSub).margin({ top: 3 })
        }
        .layoutWeight(1)
        .padding({ top: 10, bottom: 10 })
        .backgroundColor(ZeroTheme.cardBg)
        .borderRadius(ZeroTheme.radiusM)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
      .margin({ top: 12 })

      // 时间维度
      Row({ space: 8 }) {
        ForEach(this.periods, (p: string) => {
          Text(p)
            .fontSize(14)
            .fontColor(this.period === p ? ZeroTheme.textLight : ZeroTheme.textMain)
            .padding({ left: 22, right: 22, top: 7, bottom: 7 })
            .backgroundColor(this.period === p ? ZeroTheme.primary : ZeroTheme.cardBg)
            .borderRadius(20)
            .onClick(() => {
              this.period = p
              const ctx = getContext(this) as common.UIAbilityContext
              this.loadCharts(ctx)
            })
        }, (p: string) => p)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
      .margin({ top: 14 })

      Scroll() {
        Column() {
          // 趋势图
          Column() {
            Row() {
              Text(`减排趋势 (${this.period})`)
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
              Blank()
              Text(this.trendMode === 'line' ? '折线' : '柱状')
                .fontSize(11).fontColor(ZeroTheme.primary)
            }.width('100%')

            TrendChart({ points: this.trend, mode: this.trendMode })
              .margin({ top: 10 })
          }
          .alignItems(HorizontalAlign.Start)
          .padding(ZeroTheme.padM)
          .backgroundColor(ZeroTheme.cardBg)
          .borderRadius(ZeroTheme.radiusM)

          // 分类占比
          Column() {
            Text('分类减排占比')
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
            PieChart({ slices: this.slices, centerLabel: 'kg 累计' })
            ForEach(this.slices, (s: PieSlice) => {
              Row() {
                Circle({ width: 10, height: 10 }).fill(s.color)
                Text(`${s.icon} ${s.label}`)
                  .fontSize(13).fontColor(ZeroTheme.textMain).margin({ left: 8 })
                Blank()
                Text(`${s.value.toFixed(2)} kg`)
                  .fontSize(13).fontColor(ZeroTheme.textMain)
                Text(` ${this.pieTotal > 0 ? (s.value / this.pieTotal * 100).toFixed(0) : '0'}%`)
                  .fontSize(13).fontColor(ZeroTheme.textSub)
              }
              .width('100%')
              .padding({ top: 6, bottom: 6 })
            }, (s: PieSlice) => s.label)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor(ZeroTheme.cardBg)
          .borderRadius(ZeroTheme.radiusM)
          .margin({ top: 12 })

          // 碳画像雷达
          Column() {
            Row() {
              Text('碳画像 · 五类均衡度')
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
              Blank()
              Text('越均衡越健康')
                .fontSize(11).fontColor(ZeroTheme.textSub)
            }.width('100%')
            RadarChart({
              values: this.radarValues,
              labels: ['出行', '节电', '餐饮', '回收', '习惯']
            })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor(ZeroTheme.cardBg)
          .borderRadius(ZeroTheme.radiusM)
          .margin({ top: 12 })

          // 等价物换算(数值内联读取 @State,@Builder 传参不响应刷新)
          Column() {
            Text('你的减排相当于…')
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
            Row({ space: 12 }) {
              Column() {
                Text('🚗').fontSize(26)
                Row() {
                  Text((this.totalCo2 / 0.2).toFixed(0))
                    .fontSize(20).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
                  Text(' 公里').fontSize(11).fontColor(ZeroTheme.textSub)
                }.margin({ top: 6 })
                Text('少开车').fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 2 })
              }
              .layoutWeight(1)
              .padding({ top: 14, bottom: 14 })
              .backgroundColor(ZeroTheme.bg)
              .borderRadius(ZeroTheme.radiusM)
              Column() {
                Text('🌳').fontSize(26)
                Row() {
                  Text((this.totalCo2 / 10).toFixed(1))
                    .fontSize(20).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
                  Text(' 棵').fontSize(11).fontColor(ZeroTheme.textSub)
                }.margin({ top: 6 })
                Text('种树').fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 2 })
              }
              .layoutWeight(1)
              .padding({ top: 14, bottom: 14 })
              .backgroundColor(ZeroTheme.bg)
              .borderRadius(ZeroTheme.radiusM)
              Column() {
                Text('💡').fontSize(26)
                Row() {
                  Text((this.totalCo2 / 0.57).toFixed(0))
                    .fontSize(20).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
                  Text(' 度').fontSize(11).fontColor(ZeroTheme.textSub)
                }.margin({ top: 6 })
                Text('节电').fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 2 })
              }
              .layoutWeight(1)
              .padding({ top: 14, bottom: 14 })
              .backgroundColor(ZeroTheme.bg)
              .borderRadius(ZeroTheme.radiusM)
            }
            .width('100%')
            .margin({ top: 12 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor(ZeroTheme.cardBg)
          .borderRadius(ZeroTheme.radiusM)
          .margin({ top: 12, bottom: 20 })
        }
        .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 14 })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZeroTheme.bg)
  }
}
