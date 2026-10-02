import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { Database, HistoryItem } from '../../data/Database'
import { FactorLibrary } from '../../data/FactorLibrary'
import { BehaviorCategory } from '../../model/Models'

/**
 * 记录明细页:逐条碳账本
 * 支持「时段 + 分类」双维筛选与删除,并作为看板分类扇区的下钻落点
 * 进入参数(可选):{ categoryId: string, range: string }
 */
@Entry
@Component
struct RecordListPage {
  @State items: HistoryItem[] = []
  @State rangeIdx: number = 0
  @State categoryId: string = ''
  @State sumCount: number = 0
  @State sumCo2: number = 0
  @State sumPoints: number = 0
  private rangeLabels: string[] = ['近7天', '近30天', '近90天', '近180天', '全部']
  private rangeDays: number[] = [7, 30, 90, 180, 0]
  private cats: BehaviorCategory[] = FactorLibrary.categories
  /** 分页加载:每页条数(避免大账本一次性渲染) */
  private pageSize: number = 50
  @State hasMore: boolean = false

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
    const s = await Database.filterSummary(ctx, start, '', this.categoryId)
    this.sumCount = s.count
    this.sumCo2 = s.totalCo2
    this.sumPoints = s.totalPoints
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
            .fontColor(this.rangeIdx === idx ? $r('app.color.text_light') : $r('app.color.text_main'))
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(this.rangeIdx === idx ? $r('app.color.primary') : $r('app.color.card_bg'))
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

      // 汇总条
      Row({ space: 10 }) {
        Text(`共 ${this.sumCount} 笔`).fontSize(11).fontColor($r('app.color.text_sub'))
        Text(`合计 ${this.sumCo2.toFixed(2)} kg`).fontSize(11).fontColor($r('app.color.primary'))
        Text(`${this.sumPoints} 岛币`).fontSize(11).fontColor($r('app.color.gold_deep'))
        Blank()
        Text('长按/点 ✕ 可删除').fontSize(10).fontColor($r('app.color.text_sub'))
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 10, bottom: 8 })

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
        List({ space: 8 }) {
          ForEach(this.items, (it: HistoryItem) => {
            ListItem() {
              Column({ space: 5 }) {
                Row() {
                  Text(it.icon).fontSize(16)
                  Text(it.name)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_main'))
                    .margin({ left: 7 })
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${it.co2Kg.toFixed(2)} kg`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.primary'))
                    .fontFamily(ZeroTheme.fontNum)
                }
                .width('100%')

                Row({ space: 8 }) {
                  Text(it.date).fontSize(10).fontColor($r('app.color.text_sub'))
                  Text(`${it.amount} ${it.unit}`).fontSize(10).fontColor($r('app.color.text_sub'))
                  Text(it.source)
                    .fontSize(9)
                    .fontColor(this.sourceTint(it.source))
                    .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                    .backgroundColor($r('app.color.bg'))
                    .borderRadius(999)
                  Blank()
                  Text(`+${it.points} 币`).fontSize(11).fontColor($r('app.color.gold_deep'))
                  Text('✕')
                    .fontSize(12)
                    .fontColor($r('app.color.text_sub'))
                    .padding({ left: 8, right: 2, top: 2, bottom: 2 })
                    .onClick(() => {
                      this.confirmDelete(it)
                    })
                }
                .width('100%')

                if (it.note !== '') {
                  Text(`备注:${it.note}`)
                    .fontSize(10)
                    .fontColor($r('app.color.text_sub'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                }
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(ZeroTheme.padM)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(ZeroTheme.radiusM)
            }
            .gesture(LongPressGesture().onAction(() => {
              this.confirmDelete(it)
            }))
          }, (it: HistoryItem) => `${it.id}`)

          if (this.hasMore) {
            ListItem() {
              Button(`加载更多(已显示 ${this.items.length}/${this.sumCount})`)
                .fontSize(12)
                .height(36)
                .width('100%')
                .backgroundColor($r('app.color.card_bg'))
                .fontColor($r('app.color.primary'))
                .onClick(() => {
                  this.loadPage()
                })
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, bottom: 12 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
  }
}
