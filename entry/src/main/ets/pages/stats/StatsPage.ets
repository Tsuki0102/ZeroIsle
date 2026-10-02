import { common } from '@kit.AbilityKit'
import { emitter } from '@kit.BasicServicesKit'
import { router } from '@kit.ArkUI'
import { ZeroTheme } from '../../common/Theme'
import { EVT_DATA_CHANGED } from '../../common/Common'
import { Database, Summary, DailyPoint, CategorySum } from '../../data/Database'
import { FactorLibrary } from '../../data/FactorLibrary'
import { ChartPoint, PieSlice, TrendChart, PieChart, RadarChart, catColor } from '../../components/Charts'
import { StatsStrip } from '../../components/MiniScenes'
import { ISLAND_STAGES, BehaviorCategory } from '../../model/Models'

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
  @State streakDays: number = 0
  // 分类查询:空串=全部;选中后趋势图只统计该分类
  @State catFilter: string = ''
  // 统计周期选择面板:默认收起,点击左侧胶囊弹出,节省纵向空间
  @State showPeriodMenu: boolean = false
  private periods: string[] = ['日', '周', '月', '年']
  private cats: BehaviorCategory[] = FactorLibrary.categories

  private stageIdx(): number {
    let idx: number = 0
    for (let i = 0; i < ISLAND_STAGES.length; i++) {
      if (this.totalCo2 >= ISLAND_STAGES[i].thresholdKg) {
        idx = i
      }
    }
    return idx
  }

  /** 当前周期的起始日期(与图表口径一致;空串=不限) */
  private periodStart(): string {
    if (this.period === '日') {
      return Database.dateBefore(6)
    }
    if (this.period === '周') {
      return Database.dateBefore(29)
    }
    if (this.period === '月') {
      return Database.dateBefore(179)
    }
    return ''
  }

  /** 对应「记录明细」页的时段档位 */
  private rangeLabel(): string {
    if (this.period === '日') {
      return '近7天'
    }
    if (this.period === '周') {
      return '近30天'
    }
    if (this.period === '月') {
      return '近180天'
    }
    return '全部'
  }

  private catSuffix(): string {
    return this.catFilter === '' ? '' : ` · ${FactorLibrary.categoryName(this.catFilter)}`
  }

  /** 下钻到记录明细(带上当前分类与时段) */
  private openRecords(categoryId: string): void {
    router.pushUrl({
      url: 'pages/records/RecordListPage',
      params: { categoryId: categoryId, range: this.rangeLabel() }
    })
  }

  /** 数据变更回调(保存引用,退订时只移除本页订阅) */
  private readonly onDataChanged: () => void = () => {
    this.loadAll()
  }

  aboutToAppear(): void {
    emitter.on({ eventId: EVT_DATA_CHANGED }, this.onDataChanged)
    this.loadAll()
  }

  aboutToDisappear(): void {
    emitter.off(EVT_DATA_CHANGED, this.onDataChanged)
  }

  private async loadAll(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const s: Summary = await Database.summary(ctx)
    this.totalCo2 = s.totalCo2
    this.todayCo2 = s.todayCo2
    this.totalCount = s.count
    this.totalPoints = s.totalPoints
    this.streakDays = await Database.streak(ctx)
    await this.loadCharts(ctx)
  }

  private async loadCharts(ctx: common.UIAbilityContext): Promise<void> {
    // 口径与文案严格一致:日=近7日折线;周=近30天按周柱;月=近6个月按月柱;年=全部按年柱
    let days: number = 7
    let groupMode: string = 'day'
    if (this.period === '周') {
      days = 30
      groupMode = 'week'
    } else if (this.period === '月') {
      days = 180
      groupMode = 'month'
    } else if (this.period === '年') {
      days = 3650
      groupMode = 'year'
    }
    this.trendMode = this.period === '日' ? 'line' : 'bar'
    const daily: DailyPoint[] = await Database.dailySeries(ctx, days, this.catFilter)
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
      // 分桶:key 承担聚合与排序(跨年同月不合并),label 仅用于轴显示。
      // 注意 sorted 里存 key,取值也用 key —— 月模式 label(9月)≠key(2026-09),
      // 若用 label 查桶会恒取到 0(历史 bug:月视图恒为空)。
      const buckets: Map<string, number> = new Map()
      const labelByKey: Map<string, string> = new Map()
      const order: string[] = []
      for (const d of daily) {
        const parts: string[] = d.date.split('-')
        let key: string = ''
        let label: string = ''
        if (groupMode === 'week') {
          const daysAgo: number = Math.round((today.getTime() - new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])).getTime()) / 86400000)
          const bi: number = Math.floor(daysAgo / 7)
          const start: string = Database.dateBefore(bi * 7 + 6)
          const sp: string[] = start.split('-')
          key = `${Number(sp[1])}.${Number(sp[2])}`
          label = key
        } else if (groupMode === 'month') {
          // 以 年-月 作为唯一键,避免跨年同月(如两个 1 月)被错误合并;轴标签仍显示 X月
          key = `${parts[0]}-${parts[1]}`
          label = `${Number(parts[1])}月`
        } else {
          key = parts[0]
          label = key
        }
        if (!buckets.has(key)) {
          buckets.set(key, 0)
          labelByKey.set(key, label)
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
        cp.label = labelByKey.get(k) ?? k
        cp.value = buckets.get(k) ?? 0
        trend.push(cp)
      }
    }
    this.trend = trend

    // 分类占比 + 雷达(随所选周期联动:日=近7天 / 周=近30天 / 月=近6个月 / 年=全部)
    const cats: CategorySum[] = await Database.categoryStats(ctx, this.periodStart(), '')
    const slices: PieSlice[] = []
    let pieSum: number = 0
    for (const c of cats) {
      const sl = new PieSlice()
      sl.id = c.categoryId
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

  /** 周期显示名:与统计窗口一致,胶囊与弹出面板统一使用 */
  private periodLabel(p: string): string {
    if (p === '日') {
      return '近7天'
    }
    if (p === '周') {
      return '近30天'
    }
    if (p === '月') {
      return '近6个月'
    }
    return '全部'
  }

  /** 选择统计周期:关闭面板并刷新图表 */
  private selectPeriod(p: string): void {
    this.period = p
    this.showPeriodMenu = false
    const ctx = getContext(this) as common.UIAbilityContext
    this.loadCharts(ctx)
  }

  /** 统计周期选择面板(玻璃卡片,随主题) */
  @Builder
  periodMenuBuilder() {
    Column() {
      ForEach(this.periods, (p: string) => {
        Row() {
          Text(this.periodLabel(p))
            .fontSize(14)
            .fontWeight(this.period === p ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.period === p ? $r('app.color.primary') : $r('app.color.text_main'))
          Blank()
          if (this.period === p) {
            Text('✓')
              .fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 11, bottom: 11 })
        .borderRadius(12)
        .backgroundColor(this.period === p ? $r('app.color.primary_light') : Color.Transparent)
        .onClick(() => {
          this.selectPeriod(p)
        })
      }, (p: string) => p)
    }
    .width(172)
    .padding(6)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.hairline') })
  }

  build() {
    Column() {
      // 标题(删除副标题,四页统一)
      Text('碳足迹看板')
        .fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        .width('100%')
        .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      // 筛选行:统计周期(紧凑胶囊,点击弹出选择面板,默认收起不占整行) + 分类横向滚动,
      // 合并为一行,替代原先「四个周期 chips 一整行 + 分类一整行」的两行占用
      Row({ space: 8 }) {
        Row({ space: 6 }) {
          Image($rawfile('icons/ic_bill.svg'))
            .width(14).height(14).fillColor($r('app.color.primary'))
          Text(this.periodLabel(this.period))
            .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
          Text('▾')
            .fontSize(10).fontColor($r('app.color.text_sub'))
            .rotate({ angle: this.showPeriodMenu ? 180 : 0 })
            .animation({ duration: 160, curve: Curve.EaseOut })
        }
        .padding({ left: 13, right: 11, top: 8, bottom: 8 })
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(999)
        .border({ width: 1, color: $r('app.color.hairline') })
        .onClick(() => {
          this.showPeriodMenu = !this.showPeriodMenu
        })
        .bindPopup(this.showPeriodMenu, {
          builder: this.periodMenuBuilder,
          placement: Placement.BottomLeft,
          popupColor: Color.Transparent,
          enableArrow: false,
          autoCancel: true,
          mask: { color: 'rgba(12,26,23,0.16)' },
          offset: { x: -4, y: 8 }
        })

        // 分类查询:选中后趋势图只统计该分类
        Scroll() {
          Row({ space: 6 }) {
            Text('全部分类')
              .fontSize(12)
              .fontColor(this.catFilter === '' ? $r('app.color.text_light') : $r('app.color.text_main'))
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .backgroundColor(this.catFilter === '' ? $r('app.color.brand_deep') : $r('app.color.card_bg'))
              .borderRadius(999)
              .onClick(() => {
                this.catFilter = ''
                const ctx = getContext(this) as common.UIAbilityContext
                this.loadCharts(ctx)
              })
            ForEach(this.cats, (c: BehaviorCategory) => {
              Text(`${c.icon} ${c.name}`)
                .fontSize(12)
                .fontColor(this.catFilter === c.id ? $r('app.color.text_light') : $r('app.color.text_main'))
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .backgroundColor(this.catFilter === c.id ? $r('app.color.brand_deep') : $r('app.color.card_bg'))
                .borderRadius(999)
                .onClick(() => {
                  this.catFilter = c.id
                  const ctx = getContext(this) as common.UIAbilityContext
                  this.loadCharts(ctx)
                })
            }, (c: BehaviorCategory) => c.id)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
      .margin({ top: 14 })

      Scroll() {
        Column() {
          // 岛屿晴空动画场景条(树木随阶段生长)+ 玻璃数据牌
          Stack({ alignContent: Alignment.BottomStart }) {
            StatsStrip({ stage: this.stageIdx() })
            Row({ space: 8 }) {
              Text(`累计 ${this.totalCo2.toFixed(1)} kg CO₂e`)
                .fontSize(12).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
                .fontFamily(ZeroTheme.fontNum)
              Text(`连续打卡 ${this.streakDays} 天`)
                .fontSize(10).fontColor($r('app.color.text_sub'))
            }
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor('rgba(255,255,255,0.8)')
            .borderRadius(999)
            .margin({ left: 12, bottom: 10 })
          }
          .width('100%')
          .height(128)
          .borderRadius(ZeroTheme.radiusL)
          .clip(true)
          .margin({ top: 12 })

          Row({ space: 8 }) {
            Row({ space: 5 }) {
              Image($rawfile('icons/ic_calc.svg')).width(14).height(14).fillColor($r('app.color.primary'))
              Text(`今日 ${this.todayCo2.toFixed(2)} kg`).fontSize(11).fontColor($r('app.color.text_main'))
            }
            .padding({ left: 11, right: 11, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(14)
            Row({ space: 5 }) {
              Image($rawfile('icons/ic_book.svg')).width(14).height(14).fillColor($r('app.color.primary'))
              Text(`记录 ${this.totalCount} 笔`).fontSize(11).fontColor($r('app.color.text_main'))
            }
            .padding({ left: 11, right: 11, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(14)
            Row({ space: 5 }) {
              Image($rawfile('icons/ic_coin.svg')).width(14).height(14).fillColor($r('app.color.gold_deep'))
              Text(`岛币 ${this.totalPoints} 分`).fontSize(11).fontColor($r('app.color.text_main'))
            }
            .padding({ left: 11, right: 11, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(14)
            Blank()
            Row({ space: 3 }) {
              Image($rawfile('icons/ic_book.svg')).width(13).height(13).fillColor($r('app.color.primary'))
              Text('明细').fontSize(11).fontColor($r('app.color.primary'))
              Text('›').fontSize(12).fontColor($r('app.color.primary'))
            }
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(14)
            .onClick(() => {
              this.openRecords(this.catFilter)
            })
          }
          .width('100%')
          .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
          .margin({ top: 10 })

          // 空数据态(D6):插画式引导,替代冷冰冰的空图表
          if (this.totalCount === 0) {
            Column({ space: 10 }) {
              Column() {
                Image($rawfile('icons/ic_leaf.svg'))
                  .width(34).height(34).fillColor($r('app.color.text_light'))
              }
              .justifyContent(FlexAlign.Center)
              .width(76)
              .height(76)
              .borderRadius(26)
              .backgroundColor($r('app.color.primary'))
              .opacity(0.9)

              Text('你的岛屿还在等第一笔记录')
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              Text('去「记」页骑车 3 公里或光盘打卡,\n趋势图和碳画像就会开始生长')
                .fontSize(12).fontColor($r('app.color.text_sub')).lineHeight(19).textAlign(TextAlign.Center)
            }
            .alignItems(HorizontalAlign.Center)
            .width('100%')
            .padding({ top: 34, bottom: 34 })
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(ZeroTheme.radiusL)
          }

          // 趋势图
          if (this.totalCount > 0) {
            Column() {
            Row() {
              Image($rawfile('icons/ic_bill.svg')).width(16).height(16).fillColor($r('app.color.primary'))
              Text(`减排趋势 (${this.periodLabel(this.period)}${this.catSuffix()})`)
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
                .margin({ left: 6 })
              Blank()
              Text(this.trendMode === 'line' ? '折线' : '柱状')
                .fontSize(11).fontColor($r('app.color.primary'))
            }.width('100%')

            TrendChart({ points: this.trend, mode: this.trendMode })
              .margin({ top: 10 })
          }
          .alignItems(HorizontalAlign.Start)
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(ZeroTheme.radiusM)
          .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
          }

          // 分类占比
          if (this.totalCount > 0) {
          Column() {
            Row({ space: 6 }) {
              Image($rawfile('icons/ic_calc.svg')).width(16).height(16).fillColor($r('app.color.primary'))
              Text(`分类减排占比 (${this.periodLabel(this.period)})`).fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              Blank()
              Text('点分类看明细 ›').fontSize(10).fontColor($r('app.color.text_sub'))
            }.width('100%')
            PieChart({ slices: this.slices, centerLabel: 'kg 累计' })
            ForEach(this.slices, (s: PieSlice) => {
              Row() {
                Column().width(10).height(10).borderRadius(999).backgroundColor(s.color)
                  .hitTestBehavior(HitTestMode.None)
                Text(`${s.icon} ${s.label}`)
                  .fontSize(13)
                  .fontWeight(this.catFilter === s.id ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor($r('app.color.text_main')).margin({ left: 8 })
                Blank()
                Text(`${s.value.toFixed(2)} kg`)
                  .fontSize(13).fontColor($r('app.color.text_main'))
                Text(` ${this.pieTotal > 0 ? (s.value / this.pieTotal * 100).toFixed(0) : '0'}%`)
                  .fontSize(13).fontColor($r('app.color.text_sub'))
                Text('›')
                  .fontSize(12).fontColor($r('app.color.text_sub')).margin({ left: 5 })
              }
              .width('100%')
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .backgroundColor(this.catFilter === s.id ? $r('app.color.bg_deep') : $r('app.color.card_bg'))
              .borderRadius(10)
              .onClick(() => {
                // 分类下钻:查看该分类的逐条明细(继承当前周期)
                this.openRecords(s.id)
              })
            }, (s: PieSlice) => s.label)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(ZeroTheme.radiusM)
          .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
          .margin({ top: 12 })
          }

          // 碳画像雷达
          if (this.totalCount > 0) {
          Column() {
            Row() {
              Image($rawfile('icons/ic_rank.svg')).width(16).height(16).fillColor($r('app.color.primary'))
              Text('碳画像 · 五类均衡度')
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
                .margin({ left: 6 })
              Blank()
              Text('越均衡越健康')
                .fontSize(11).fontColor($r('app.color.text_sub'))
            }.width('100%')
            RadarChart({
              values: this.radarValues,
              labels: ['出行', '节电', '餐饮', '回收', '习惯']
            })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(ZeroTheme.radiusM)
          .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
          .margin({ top: 12 })
          }

          // 等价物换算(数值内联读取 @State,@Builder 传参不响应刷新)
          if (this.totalCount > 0) {
          Column() {
            Row({ space: 6 }) {
              Image($rawfile('icons/ic_leaf.svg')).width(16).height(16).fillColor($r('app.color.life'))
              Text('你的减排相当于…').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            }
            Row({ space: 12 }) {
              Column() {
                Text('🚗').fontSize(26)
                Row() {
                  Text((this.totalCo2 / 0.2).toFixed(0))
                    .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
                  Text(' 公里').fontSize(11).fontColor($r('app.color.text_sub'))
                }.margin({ top: 6 })
                Text('少开车').fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 2 })
              }
              .layoutWeight(1)
              .padding({ top: 14, bottom: 14 })
              .backgroundColor($r('app.color.bg'))
              .borderRadius(ZeroTheme.radiusM)
              Column() {
                Text('🌳').fontSize(26)
                Row() {
                  Text((this.totalCo2 / 10).toFixed(1))
                    .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
                  Text(' 棵').fontSize(11).fontColor($r('app.color.text_sub'))
                }.margin({ top: 6 })
                Text('种树').fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 2 })
              }
              .layoutWeight(1)
              .padding({ top: 14, bottom: 14 })
              .backgroundColor($r('app.color.bg'))
              .borderRadius(ZeroTheme.radiusM)
              Column() {
                Text('💡').fontSize(26)
                Row() {
                  Text((this.totalCo2 / 0.57).toFixed(0))
                    .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
                  Text(' 度').fontSize(11).fontColor($r('app.color.text_sub'))
                }.margin({ top: 6 })
                Text('节电').fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 2 })
              }
              .layoutWeight(1)
              .padding({ top: 14, bottom: 14 })
              .backgroundColor($r('app.color.bg'))
              .borderRadius(ZeroTheme.radiusM)
            }
            .width('100%')
            .margin({ top: 12 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(ZeroTheme.radiusM)
          .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
          .margin({ top: 12, bottom: 20 })
          }
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
    .constraintSize({ maxWidth: 720 })
    .backgroundColor($r('app.color.bg'))
  }
}
