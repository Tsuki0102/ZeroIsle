import { common } from '@kit.AbilityKit'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { FactorLibrary } from '../../data/FactorLibrary'
import { Database, Summary } from '../../data/Database'
import { BehaviorCategory, BehaviorFactor } from '../../model/Models'
import { catColor } from '../../components/Charts'
import { VisionService, OcrOutcome, QrOutcome } from '../../service/VisionService'
import { SemanticParser, ParsedItem } from '../../service/SemanticParser'

/** 抄表口径统一走因子库(E01 节约用电),预览与入库同源 */
const METER_FACTOR_ID: string = 'E01'

/** 录入页「记」:行为选择 → 数量 → 实时核算 → 入库;拍照识别 + OCR 抄表 */
@Component
export struct RecordPage {
  @State selectedCategory: string = 'travel'
  @State selectedFactor: BehaviorFactor | null = null
  @State amountStr: string = '1'
  @State sheet: string = 'none'
  @State ocrText: string = ''
  @State ocrItems: ParsedItem[] = []
  @State meterDigits: string[] = []
  @State meterCurrent: string = ''
  @State meterLast: string = ''
  @State lastSource: string = '拍照'
  @State todayCount: number = 0
  @State todayCo2: number = 0

  /** 数据变更回调(保存引用,退订时只移除本页订阅) */
  private readonly onDataChanged: () => void = () => {
    this.loadToday()
  }

  aboutToAppear(): void {
    emitter.on({ eventId: EVT_DATA_CHANGED }, this.onDataChanged)
    this.loadToday()
  }

  aboutToDisappear(): void {
    emitter.off(EVT_DATA_CHANGED, this.onDataChanged)
  }

  private async loadToday(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const s: Summary = await Database.summary(ctx)
    this.todayCount = s.todayCount
    this.todayCo2 = s.todayCo2
  }

  private runPhotoCam(): void {
    toast('对着低碳行为拍一张…')
    const ctx = getContext(this) as common.UIAbilityContext
    VisionService.recognizeFromCamera(ctx).then((o: OcrOutcome) => {
      this.handleOcr(o)
    })
  }

  private runPhoto(): void {
    toast('选择一张低碳行为相关照片…')
    VisionService.recognizeFromGallery().then((o: OcrOutcome) => {
      this.handleOcr(o)
    })
  }

  private handleOcr(o: OcrOutcome): void {
    if (!o.ok) {
      toast(o.msg)
      return
    }
    this.lastSource = '拍照'
    this.ocrText = o.text
    const r = SemanticParser.parse(o.text)
    this.ocrItems = r.items
    this.sheet = 'photo'
  }

  /** 扫码录入:相册选共享单车骑行码 → ScanKit 二维码检测 → 自动换算骑行里程 */
  private runRideCode(): void {
    toast('选一张共享单车骑行码图片…')
    VisionService.decodeQrFromGallery().then((q: QrOutcome) => {
      if (!q.ok) {
        toast(q.msg)
        return
      }
      const item = this.parseRidePayload(q.payload)
      if (item === null) {
        toast(`不是零屿支持的骑行码:${q.payload.substring(0, 24)}`)
        return
      }
      this.lastSource = '扫码'
      this.ocrText = `扫码结果:${q.payload}`
      this.ocrItems = [item]
      this.sheet = 'photo'
    })
  }

  /** 骑行码协议:zeroisle://ride?km=3.2(演示样例图已内置,真实场景可对接单车平台开屏码) */
  private parseRidePayload(payload: string): ParsedItem | null {
    const m: RegExpMatchArray | null = payload.match(/zeroisle:\/\/ride\?km=([\d.]+)/)
    if (m === null) {
      return null
    }
    const km: number = parseFloat(m[1])
    if (isNaN(km) || km <= 0 || km > 100) {
      return null
    }
    const f = FactorLibrary.byId('T01')
    const item = new ParsedItem()
    item.factorId = f.id
    item.name = f.name
    item.icon = '🚲'
    item.amount = km
    item.unit = f.unit
    item.co2Kg = km * f.factor
    item.points = Math.round(item.co2Kg * 10)
    return item
  }

  private runMeter(): void {
    toast('对着宿舍电表拍一张…')
    VisionService.recognizeFromGallery().then((o: OcrOutcome) => {
      if (!o.ok) {
        toast(o.msg)
        return
      }
      this.ocrText = o.text
      this.meterDigits = VisionService.extractNumbers(o.text)
      this.meterCurrent = this.meterDigits.length > 0 ? this.meterDigits[this.meterDigits.length - 1] : ''
      this.meterLast = ''
      this.sheet = 'meter'
    })
  }

  private savePhotoItems(): void {
    if (this.ocrItems.length === 0) {
      toast('没识别出低碳行为,可改用手动录入')
      this.sheet = 'none'
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    const items: ParsedItem[] = this.ocrItems
    const total: number = items.length
    let done: number = 0
    let ok: number = 0
    const finish = (): void => {
      if (ok > 0) {
        emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      }
      if (ok === total) {
        toast(`已从照片记录 ${total} 条行为!`)
        this.sheet = 'none'
      } else {
        toast(`成功 ${ok} 条,失败 ${total - ok} 条,请重试`)
      }
    }
    for (const it of items) {
      Database.insertRecord(ctx, it.factorId, it.amount, this.lastSource, '').then(() => {
        ok++
        done++
        if (done === total) {
          finish()
        }
      }).catch(() => {
        done++
        if (done === total) {
          finish()
        }
      })
    }
  }

  private saveMeter(): void {
    const cur: number = parseFloat(this.meterCurrent)
    const last: number = parseFloat(this.meterLast)
    if (isNaN(cur) || isNaN(last) || cur <= last) {
      toast('请确认读数:当前读数应大于上次读数')
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    Database.insertRecord(ctx, METER_FACTOR_ID, cur - last, '抄表', `读数 ${last}→${cur}`).then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      this.ocrText = ''
      this.meterDigits = []
      toast(`已记录节电 ${cur - last} 度(抄表)`)
      this.sheet = 'none'
    }).catch(() => {
      toast('保存失败,请重试')
    })
  }

  private catSvg(categoryId: string): string {
    const map: Map<string, string> = new Map()
    map.set('travel', 'ic_bike')
    map.set('energy', 'ic_bolt')
    map.set('food', 'ic_bowl')
    map.set('recycle', 'ic_recycle')
    map.set('habit', 'ic_leaf')
    const hit = map.get(categoryId)
    return hit ?? 'ic_leaf'
  }

  private amountValue(): number {
    const v: number = parseFloat(this.amountStr)
    if (isNaN(v) || v <= 0) {
      return 0
    }
    return v
  }

  private co2Preview(): number {
    if (this.selectedFactor === null) {
      return 0
    }
    return this.amountValue() * this.selectedFactor.factor
  }

  private save(): void {
    const f = this.selectedFactor
    if (f === null) {
      return
    }
    const amount: number = this.amountValue()
    if (amount <= 0) {
      toast('请输入有效的数量')
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    Database.insertRecord(ctx, f.id, amount, '手动', '').then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      this.selectedFactor = null
      this.amountStr = '1'
      toast(`已记录「${f.name}」+${Math.round(amount * f.factor * 10)} 岛币`)
    }).catch(() => {
      toast('保存失败,请重试')
    })
  }

  private isSheetOn(): boolean {
    return this.selectedFactor !== null || this.sheet !== 'none'
  }

  private closeSheet(): void {
    this.selectedFactor = null
    this.sheet = 'none'
  }

  @Builder
  sheetPanel() {
    if (this.selectedFactor !== null) {
          Column() {
        Row() {
          Text(`${FactorLibrary.categoryIcon(this.selectedFactor.categoryId)} ${this.selectedFactor.name}`)
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Blank()
          Text('✕')
            .fontSize(18).fontColor($r('app.color.text_sub'))
            .padding(6)
            .onClick(() => {
              this.selectedFactor = null
            })
        }.width('100%')
  
        Text(`口径:${this.selectedFactor.tip}`)
          .fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 6 })
  
        Row({ space: 8 }) {
          Button('−')
            .fontSize(18).width(44).height(44)
            .backgroundColor($r('app.color.bg')).fontColor($r('app.color.text_main'))
            .onClick(() => {
              const v: number = this.amountValue()
              if (v > 1) {
                this.amountStr = `${Math.round(v - 1)}`
              }
            })
          TextInput({ text: this.amountStr })
            .type(InputType.NUMBER_DECIMAL)
            .fontSize(18)
            .height(44)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.bg'))
            .onChange((value: string) => {
              this.amountStr = value
            })
          Button('+')
            .fontSize(18).width(44).height(44)
            .backgroundColor($r('app.color.bg')).fontColor($r('app.color.text_main'))
            .onClick(() => {
              const v: number = this.amountValue()
              this.amountStr = `${Math.round(v + 1)}`
            })
          Text(this.selectedFactor.unit)
            .fontSize(14).fontColor($r('app.color.text_main')).width(40)
        }
        .width('100%')
        .margin({ top: 14 })
  
        Row({ space: 8 }) {
          ForEach([1, 3, 5, 10], (q: number) => {
            Text(`${q}`)
              .fontSize(13)
              .fontColor(this.amountStr === `${q}` ? $r('app.color.text_light') : $r('app.color.text_main'))
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor(this.amountStr === `${q}` ? $r('app.color.primary') : $r('app.color.bg'))
              .borderRadius(14)
              .onClick(() => {
                this.amountStr = `${q}`
              })
          }, (q: number) => `${q}`)
        }
        .width('100%')
        .margin({ top: 10 })
  
        // 实时核算预览
        Row() {
          Text(`预计减排 ${this.co2Preview().toFixed(2)} kg CO₂e`)
            .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.primary'))
          Blank()
          Text(`+${Math.round(this.co2Preview() * 10)} 岛币`)
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent'))
        }
        .width('100%')
        .padding(ZeroTheme.padM)
        .backgroundColor($r('app.color.primary_light'))
        .borderRadius(ZeroTheme.radiusM)
        .margin({ top: 14 })
  
        Button('保存并记录')
          .fontSize(15)
          .width('100%')
          .height(44)
          .backgroundColor($r('app.color.primary'))
          .margin({ top: 14 })
          .onClick(() => {
            this.save()
          })
      }
      .alignItems(HorizontalAlign.Start)
      .padding(ZeroTheme.padL)
      .backgroundColor($r('app.color.card_bg'))
    } else if (this.sheet === 'photo') {
      this.photoPanel()
    } else if (this.sheet === 'meter') {
      this.meterPanel()
    }
  }

  /** 拍照/扫码 AI 识别确认面板 */
  @Builder
  photoPanel() {
    Column() {
      Row() {
        Text('🤖 零屿 AI 识别结果').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Text('✕').fontSize(18).fontColor($r('app.color.text_sub'))
          .onClick(() => {
            this.sheet = 'none'
          })
      }.width('100%')

      Text(this.ocrText.length > 0 ? `照片文字:「${this.ocrText.substring(0, 60)}」` : '照片中未检出文字')
        .fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 6 })

      if (this.ocrItems.length > 0) {
        ForEach(this.ocrItems, (it: ParsedItem) => {
          Row() {
            Text(it.icon).fontSize(15)
            Text(`${it.name} × ${it.amount} ${it.unit}`)
              .fontSize(13).fontColor($r('app.color.text_main')).margin({ left: 8 })
            Blank()
            Text(`+${it.points} 币`).fontSize(12).fontColor($r('app.color.accent'))
          }
          .width('100%')
          .padding({ top: 7, bottom: 7 })
        }, (it: ParsedItem) => it.factorId + it.amount)
      } else {
        Text('没识别出明确的低碳行为,建议改用手动录入')
          .fontSize(12).fontColor($r('app.color.danger')).margin({ top: 8 })
      }

      Button(this.ocrItems.length > 0 ? `确认记录 ${this.ocrItems.length} 条` : '知道了')
        .fontSize(14)
        .width('100%')
        .height(42)
        .backgroundColor(this.ocrItems.length > 0 ? $r('app.color.primary') : $r('app.color.bg'))
        .fontColor(this.ocrItems.length > 0 ? $r('app.color.text_light') : $r('app.color.text_sub'))
        .margin({ top: 12 })
        .onClick(() => {
          this.savePhotoItems()
        })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(ZeroTheme.padL)
    .backgroundColor($r('app.color.card_bg'))
  }

  /** 电表抄表面板 */
  @Builder
  meterPanel() {
    Column() {
      Row() {
        Text('🔍 电表抄表').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Text('✕').fontSize(18).fontColor($r('app.color.text_sub'))
          .onClick(() => {
            this.sheet = 'none'
          })
      }.width('100%')

      Text(this.meterDigits.length > 0
        ? `识别到数字:${this.meterDigits.join(' / ')}`
        : `照片文字:「${this.ocrText.substring(0, 40)}」(未检出数字,可手动填写)`)
        .fontSize(12).fontColor($r('app.color.text_sub')).margin({ top: 6 })

      if (this.meterDigits.length > 0) {
        Row({ space: 6 }) {
          Text('点选当前读数:').fontSize(11).fontColor($r('app.color.text_sub'))
          ForEach(this.meterDigits.slice(0, 4), (d: string) => {
            Text(d)
              .fontSize(12)
              .fontColor(this.meterCurrent === d ? $r('app.color.text_light') : $r('app.color.text_main'))
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(this.meterCurrent === d ? $r('app.color.primary') : $r('app.color.bg'))
              .borderRadius(8)
              .onClick(() => {
                this.meterCurrent = d
              })
          }, (d: string) => d)
        }
        .width('100%')
        .margin({ top: 10 })
      }

      Row({ space: 8 }) {
        Text('当前读数').fontSize(12).fontColor($r('app.color.text_sub'))
        TextInput({ text: this.meterCurrent })
          .type(InputType.NUMBER_DECIMAL)
          .fontSize(14).height(38).layoutWeight(1)
          .textAlign(TextAlign.Center).backgroundColor($r('app.color.bg'))
          .onChange((v: string) => {
            this.meterCurrent = v
          })
      }
      .width('100%')
      .margin({ top: 10 })

      Row({ space: 8 }) {
        Text('上次读数').fontSize(12).fontColor($r('app.color.text_sub'))
        TextInput({ text: this.meterLast, placeholder: '如 3250' })
          .type(InputType.NUMBER_DECIMAL)
          .fontSize(14).height(38).layoutWeight(1)
          .textAlign(TextAlign.Center).backgroundColor($r('app.color.bg'))
          .onChange((v: string) => {
            this.meterLast = v
          })
      }
      .width('100%')
      .margin({ top: 8 })

      Row() {
        Text(`本次用电 ${((parseFloat(this.meterCurrent) || 0) - (parseFloat(this.meterLast) || 0)).toFixed(0)} 度`)
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
        Blank()
        Text(`≈ +${Math.round(((parseFloat(this.meterCurrent) || 0) - (parseFloat(this.meterLast) || 0)) * FactorLibrary.byId(METER_FACTOR_ID).factor * 10)} 岛币`)
          .fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent'))
      }
      .width('100%')
      .padding(ZeroTheme.padM)
      .backgroundColor($r('app.color.primary_light'))
      .borderRadius(ZeroTheme.radiusM)
      .margin({ top: 12 })

      Button('确认记录节电')
        .fontSize(14)
        .width('100%')
        .height(42)
        .backgroundColor($r('app.color.primary'))
        .margin({ top: 12 })
        .onClick(() => {
          this.saveMeter()
        })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(ZeroTheme.padL)
    .backgroundColor($r('app.color.card_bg'))
  }

  build() {
    Stack() {
      Column() {
        // 标题 + AI 录入入口
        Column() {
          Text('碳账记录').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))

          Scroll() {
            Row({ space: 8 }) {
              Row({ space: 5 }) {
                Image($rawfile('icons/ic_camera.svg')).width(15).height(15).fillColor($r('app.color.primary'))
                Text('拍照识别').fontSize(12).fontColor($r('app.color.primary'))
              }
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.primary_light'))
              .borderRadius(16)
              .onClick(() => {
                this.runPhotoCam()
              })
              Row({ space: 5 }) {
                Image($rawfile('icons/ic_bill.svg')).width(15).height(15).fillColor($r('app.color.primary'))
                Text('相册识别').fontSize(12).fontColor($r('app.color.primary'))
              }
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.primary_light'))
              .borderRadius(16)
              .onClick(() => {
                this.runPhoto()
              })
              Row({ space: 5 }) {
                Image($rawfile('icons/ic_search.svg')).width(15).height(15).fillColor($r('app.color.primary'))
                Text('电表抄表').fontSize(12).fontColor($r('app.color.primary'))
              }
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.primary_light'))
              .borderRadius(16)
              .onClick(() => {
                this.runMeter()
              })
              Row({ space: 5 }) {
                Image($rawfile('icons/ic_coin.svg')).width(15).height(15).fillColor($r('app.color.primary'))
                Text('扫码录入').fontSize(12).fontColor($r('app.color.primary'))
              }
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.primary_light'))
              .borderRadius(16)
              .onClick(() => {
                this.runRideCode()
              })
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .margin({ top: 10 })

          // 今日录入概览
          Row({ space: 8 }) {
            Row({ space: 5 }) {
              Image($rawfile('icons/ic_calc.svg')).width(14).height(14).fillColor($r('app.color.primary'))
              Text(`今日 ${this.todayCount} 笔`).fontSize(11).fontColor($r('app.color.primary'))
            }
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor($r('app.color.primary_light'))
            .borderRadius(14)
            Row({ space: 5 }) {
              Image($rawfile('icons/ic_leaf.svg')).width(14).height(14).fillColor($r('app.color.life'))
              Text(`已减排 ${this.todayCo2.toFixed(2)} kg`).fontSize(11).fontColor($r('app.color.life_deep'))
            }
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor($r('app.color.bg_deep'))
            .borderRadius(14)
            Blank()
          }
          .width('100%')
          .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

        // 分类 chips
        Scroll() {
          Row({ space: 8 }) {
            ForEach(FactorLibrary.categories, (cat: BehaviorCategory) => {
              Row({ space: 5 }) {
                Image($rawfile(`icons/${this.catSvg(cat.id)}.svg`))
                  .width(15).height(15)
                  .fillColor(this.selectedCategory === cat.id ? $r('app.color.text_light') : catColor(cat.id))
                Text(cat.name)
                  .fontSize(13)
                  .fontColor(this.selectedCategory === cat.id ? $r('app.color.text_light') : $r('app.color.text_main'))
              }
              .padding({ left: 13, right: 13, top: 7, bottom: 7 })
              .backgroundColor(this.selectedCategory === cat.id ? catColor(cat.id) : $r('app.color.card_bg'))
              .borderRadius(20)
              .onClick(() => {
                this.selectedCategory = cat.id
              })
            }, (cat: BehaviorCategory) => cat.id)
          }
          .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .margin({ top: 12 })

        // 行为列表
        List({ space: 8 }) {
          ForEach(FactorLibrary.byCategory(this.selectedCategory), (f: BehaviorFactor) => {
            ListItem() {
              Row() {
                Column() {
                  Image($rawfile(`icons/${this.catSvg(f.categoryId)}.svg`))
                    .width(20).height(20).fillColor($r('app.color.text_light'))
                }
                .justifyContent(FlexAlign.Center)
                .width(42).height(42)
                .borderRadius(14)
                .backgroundColor(catColor(f.categoryId))

                Column() {
                  Text(`${FactorLibrary.sceneLabel(f.scene)} · ${f.name}`)
                    .fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                  Text(f.tip).fontSize(10).fontColor($r('app.color.text_sub')).margin({ top: 3 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 10 })

                Column() {
                  Text(`${f.factor.toFixed(2)}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
                  Text(`kg CO₂e / ${f.unit}`).fontSize(9).fontColor($r('app.color.text_sub'))
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .padding(ZeroTheme.padM)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(ZeroTheme.radiusM)
              .shadow({ radius: 10, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 3 })
              .clickEffect({ level: ClickEffectLevel.LIGHT })
              .onClick(() => {
                this.selectedFactor = f
                this.amountStr = '1'
              })
            }
          }, (f: BehaviorFactor) => f.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12, bottom: 12 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg'))

    }
    .width('100%')
    .height('100%')
    .bindSheet(this.isSheetOn(), (): void => {
      this.sheetPanel()
    }, {
      height: SheetSize.FIT_CONTENT,
      dragBar: false,
      showClose: false,
      backgroundColor: $r('app.color.card_bg'),
      onDisappear: () => {
        this.selectedFactor = null
        this.sheet = 'none'
      }
    })
  }
}
