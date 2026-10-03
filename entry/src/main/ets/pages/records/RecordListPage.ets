import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { Database, HistoryItem } from '../../data/Database'
import { FactorLibrary } from '../../data/FactorLibrary'
import { catColor } from '../../components/Charts'
import { BehaviorCategory } from '../../model/Models'

/** 展示行:0=日期分组头,1=记录卡片(扁平化,单 ForEach 渲染) */
class ListRow {
  kind: number = 0
  date: string = ''
  label: string = ''
  count: number = 0
  co2: number = 0
  item: HistoryItem | null = null
}

/**
 * 记录明细页:逐条碳账本
 * 支持「时段 + 分类」双维筛选与删除,并作为看板分类扇区的下钻落点
 * 进入参数(可选):{ categoryId: string, range: string }
 */
@Entry
@Component
struct RecordListPage {
  @State items: HistoryItem[] = []
  @State rows: ListRow[] = []
  @State rangeIdx: number = 0
  @State categoryId: string = ''
  @State sumCount: number = 0
  @State sumCo2: number = 0
  @State sumPoints: number = 0
  /** 分页加载:每页条数(避免大账本一次性渲染) */
  private pageSize: number = 50
  @State hasMore: boolean = false
  private rangeLabels: string[] = ['近7天', '近30天', '近90天', '近180天', '全部']
  private rangeDays: number[] = [7, 30, 90, 180, 0]
  private cats: BehaviorCategory[] = FactorLibrary.categories

  aboutToAppear(): void {
    this.readParams()
    this.load()
  }

  /** 读取路由参数(看板下钻可携带分类与时段) */
  private readParams(): void {
    try {
      const params = router.getParams() as Record<string, string>
      if (params === undefined || params === null) {
        return
      }
      if (params['categoryId'] !== undefined) {
        this.categoryId = params['categoryId']
      }
      if (params['range'] !== undefined) {
        const idx: number = this.rangeLabels.indexOf(params['range'])
        if (idx >= 0) {
          this.rangeIdx = idx
        }
      }
    } catch (err) {
      // 无参数直接进入(从「我的」页入口)
    }
  }

  private startDate(): string {
    const days: number = this.rangeDays[this.rangeIdx]
    return days === 0 ? '' : Database.dateBefore(days - 1)
  }

  private async load(): Promise<void> {
    this.items = []
    this.hasMore = false
    await this.loadPage()
  }

  /** 追加一页明细(查询 pageSize+1 条探测是否还有下一页) */
  private async loadPage(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const start: string = this.startDate()
    const rows: HistoryItem[] = await Database.historyFilter(ctx, start, '', this.categoryId,
      this.pageSize + 1, this.items.length)
    const more: boolean = rows.length > this.pageSize
    if (more) {
      rows.splice(this.pageSize, rows.length - this.pageSize)
    }
    this.items = this.items.concat(rows)
    this.hasMore = more
    this.regroup()
    const s = await Database.filterSummary(ctx, start, '', this.categoryId)
    this.sumCount = s.count
    this.sumCo2 = s.totalCo2
    this.sumPoints = s.totalPoints
  }

  /** 把按日期倒序的记录流扁平化为「分组头 + 卡片」行序列(两遍法:先按天聚桶,保证头部带当日小计且在组前) */
  private regroup(): void {
    const order: string[] = []
    const byDate: Map<string, HistoryItem[]> = new Map()
    for (const it of this.items) {
      if (!byDate.has(it.date)) {
        byDate.set(it.date, [])
        order.push(it.date)
      }
      const bucket: HistoryItem[] = byDate.get(it.date) as HistoryItem[]
      bucket.push(it)
    }
    const rows: ListRow[] = []
    for (const d of order) {
      const list: HistoryItem[] = byDate.get(d) as HistoryItem[]
      rows.push(this.headerRow(d, list.length, list.reduce((s: number, x: HistoryItem) => s + x.co2Kg, 0)))
      for (const it of list) {
        const r = new ListRow()
        r.kind = 1
        r.date = it.date
        r.item = it
        rows.push(r)
      }
    }
    this.rows = rows
  }

  private headerRow(date: string, count: number, co2: number): ListRow {
    const r = new ListRow()
    r.kind = 0
    r.date = date
    r.label = this.dayLabel(date)
    r.count = count
    r.co2 = co2
    return r
  }

  /** 日期 → 「今天 / 昨天 / M月D日 周X」 */
  private dayLabel(date: string): string {
    const today: string = Database.today()
    if (date === today) {
      return '今天'
    }
    if (date === Database.dateBefore(1)) {
      return '昨天'
    }
    const parts: string[] = date.split('-')
    if (parts.length < 3) {
      return date
    }
    const d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
    const weeks: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
    return `${Number(parts[1])}月${Number(parts[2])}日 ${weeks[d.getDay()]}`
  }

  /** 记录所属分类色(与白色 18% 混合成浅底;8位hex透明度解析不可靠,用 rgb()) */
  private catTint(it: HistoryItem): string {
    const hex: string = catColor(FactorLibrary.categoryOf(it.factorId))
    const r: number = parseInt(hex.slice(1, 3), 16)
    const g: number = parseInt(hex.slice(3, 5), 16)
    const b: number = parseInt(hex.slice(5, 7), 16)
    const mix = (c: number): number => Math.round(c * 0.18 + 255 * 0.82)
    return `rgb(${mix(r)},${mix(g)},${mix(b)})`
  }

  /** 删除单条(二次确认;删除后岛屿进度同步回退) */
  private confirmDelete(it: HistoryItem): void {
    AlertDialog.show({
      title: '删除这条记录?',
      message: `${it.date} · ${it.name} ${it.amount} ${it.unit}\n减排 ${it.co2Kg.toFixed(2)} kg、${it.points} 岛币将一并从岛屿进度中扣除。`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#D9534F',
        action: () => {
          const ctx = getContext(this) as common.UIAbilityContext
          Database.deleteRecord(ctx, it.id).then(() => {
            emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
            toast('已删除 1 条记录')
            this.load()
          })
        }
      }
    })
  }

  /** 录入来源标识色 */
  private sourceTint(src: string): string {
    if (src === '语义') {
      return '#2E7D5B'
    }
    if (src === '拍照') {
      return '#4E8FB8'
    }
    if (src === '抄表') {
      return '#D97706'
    }
    if (src === '扫码') {
      return '#7C5CBF'
    }
    if (src === '碳知实验室') {
      return '#0E7C86'
    }
    return '#6E7F8A'
  }

  /** 记录卡片 */
  @Builder
  recordCard(it: HistoryItem) {
    Row({ space: 10 }) {
      Column() {
        Text(it.icon).fontSize(17)
      }
      .justifyContent(FlexAlign.Center)
      .width(40).height(40)
      .borderRadius(13)
      .backgroundColor(this.catTint(it))

      Column({ space: 4 }) {
        Text(it.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_main'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          Text(it.date).fontSize(10).fontColor($r('app.color.text_sub'))
          Text(`${it.amount} ${it.unit}`).fontSize(10).fontColor($r('app.color.text_sub'))
          Text(it.source)
            .fontSize(9)
            .fontColor(this.sourceTint(it.source))
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .backgroundColor($r('app.color.bg'))
            .borderRadius(999)
        }
        if (it.note !== '') {
          Text(`备注:${it.note}`)
            .fontSize(10)
            .fontColor($r('app.color.text_sub'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: 3 }) {
        Text(`${it.co2Kg.toFixed(2)} kg`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary'))
          .fontFamily(ZeroTheme.fontNum)
        Text(`+${it.points} 币`)
          .fontSize(10).fontColor($r('app.color.gold_deep'))
        Text('✕')
          .fontSize(11)
          .fontColor($r('app.color.text_sub'))
          .textAlign(TextAlign.Center)
          .width(20).height(20)
          .backgroundColor($r('app.color.bg'))
          .borderRadius(999)
          .onClick(() => {
            this.confirmDelete(it)
          })
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(ZeroTheme.padM)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(ZeroTheme.radiusM)
    .shadow({ radius: 10, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 3 })
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor($r('app.color.text_main'))
          .onClick(() => {
            router.back()
          })
        Blank()
        Text('记录明细').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Row().width(22)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      // 时段筛选
      Row({ space: 8 }) {
        ForEach(this.rangeLabels, (p: string, idx: number) => {
          Text(p)
            .fontSize(12)
            .fontWeight(this.rangeIdx === idx ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.rangeIdx === idx ? $r('app.color.text_light') : $r('app.color.text_main'))
            .padding({ left: 13, right: 13, top: 6, bottom: 6 })
            .backgroundColor(this.rangeIdx === idx ? $r('app.color.primary') : $r('app.color.card_bg'))
            .border({ width: 1, color: this.rangeIdx === idx ? Color.Transparent : $r('app.color.hairline') })
            .borderRadius(999)
            .onClick(() => {
              this.rangeIdx = idx
              this.load()
            })
        }, (p: string) => p)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
      .margin({ top: 12 })

      // 分类筛选
      Scroll() {
        Row({ space: 8 }) {
          Text('全部分类')
            .fontSize(12)
            .fontColor(this.categoryId === '' ? $r('app.color.text_light') : $r('app.color.text_main'))
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .backgroundColor(this.categoryId === '' ? $r('app.color.brand_deep') : $r('app.color.card_bg'))
            .border({ width: 1, color: this.categoryId === '' ? Color.Transparent : $r('app.color.hairline') })
            .borderRadius(999)
            .onClick(() => {
              this.categoryId = ''
              this.load()
            })
          ForEach(this.cats, (c: BehaviorCategory) => {
            Text(`${c.icon} ${c.name}`)
              .fontSize(12)
              .fontColor(this.categoryId === c.id ? $r('app.color.text_light') : $r('app.color.text_main'))
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .backgroundColor(this.categoryId === c.id ? $r('app.color.brand_deep') : $r('app.color.card_bg'))
              .border({ width: 1, color: this.categoryId === c.id ? Color.Transparent : $r('app.color.hairline') })
              .borderRadius(999)
              .onClick(() => {
                this.categoryId = c.id
                this.load()
              })
          }, (c: BehaviorCategory) => c.id)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
      .margin({ top: 8 })
      .align(Alignment.Start)

      // 汇总 Hero 卡(渐变,三指标)
      Row() {
        Column({ space: 3 }) {
          Text(`${this.sumCount}`)
            .fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .fontFamily(ZeroTheme.fontNum)
          Text('笔记录').fontSize(10).fontColor('rgba(255,255,255,0.75)')
        }
        .layoutWeight(1)
        Column()
          .width(1).height(26)
          .backgroundColor('rgba(255,255,255,0.28)')
        Column({ space: 3 }) {
          Text(this.sumCo2.toFixed(2))
            .fontSize(19).fontWeight(FontWeight.Bold).fontColor(Color.White)
            .fontFamily(ZeroTheme.fontNum)
          Text('合计减排 kg').fontSize(10).fontColor('rgba(255,255,255,0.75)')
        }
        .layoutWeight(1)
        Column()
          .width(1).height(26)
          .backgroundColor('rgba(255,255,255,0.28)')
        Column({ space: 3 }) {
          Text(`${this.sumPoints}`)
            .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#EAD9B0')
            .fontFamily(ZeroTheme.fontNum)
          Text('累计岛币').fontSize(10).fontColor('rgba(255,255,255,0.75)')
        }
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: 13, bottom: 13 })
      .linearGradient({ angle: 135, colors: [[$r('app.color.brand_deep'), 0], [$r('app.color.primary'), 1]] })
      .borderRadius(ZeroTheme.radiusL)
      .shadow({ radius: 14, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 5 })
      .margin({ top: 12 })

      Text('长按卡片或点 ✕ 可删除,删除会同步回退岛屿进度')
        .fontSize(9.5).fontColor($r('app.color.text_sub'))
        .width('100%')
        .textAlign(TextAlign.End)
        .padding({ right: ZeroTheme.padL, top: 6, bottom: 2 })

      if (this.items.length === 0) {
        Column({ space: 10 }) {
          Image($rawfile('icons/ic_book.svg'))
            .width(30).height(30).fillColor($r('app.color.text_light'))
          Text(this.sumCount === 0 && this.categoryId !== '' ? '该分类下暂无记录' : '这个时段还没有记录')
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text('换个时段或分类看看,或去「记」页录入一笔低碳行为')
            .fontSize(11).fontColor($r('app.color.text_sub'))
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .layoutWeight(1)
        .padding({ bottom: 60 })
      } else {
        List({ space: 6 }) {
          ForEach(this.rows, (r: ListRow) => {
            ListItem() {
              if (r.kind === 0) {
                Row() {
                  Text(r.label)
                    .fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
                  Blank()
                  Text(`${r.count} 笔 · ${r.co2.toFixed(2)} kg`)
                    .fontSize(10).fontColor($r('app.color.text_sub'))
                }
                .width('100%')
                .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 10, bottom: 2 })
              } else {
                Column() {
                  this.recordCard(r.item as HistoryItem)
                }
                .margin({ left: ZeroTheme.padL, right: ZeroTheme.padL })
                .gesture(LongPressGesture().onAction(() => {
                  this.confirmDelete(r.item as HistoryItem)
                }))
              }
            }
          }, (r: ListRow) => (r.kind === 0 ? `h_${r.date}_${r.count}` : `i_${(r.item as HistoryItem).id}`))

          if (this.hasMore) {
            ListItem() {
              Button(`加载更多(已显示 ${this.items.length}/${this.sumCount})`)
                .fontSize(12)
                .height(36)
                .width('100%')
                .margin({ left: ZeroTheme.padL, right: ZeroTheme.padL })
                .backgroundColor($r('app.color.card_bg'))
                .fontColor($r('app.color.primary'))
                .onClick(() => {
                  this.loadPage()
                })
            }
            .margin({ top: 6 })
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ top: 4, bottom: 12 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
  }
}
