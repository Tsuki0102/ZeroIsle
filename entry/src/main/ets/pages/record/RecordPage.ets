import { common } from '@kit.AbilityKit'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { FactorLibrary } from '../../data/FactorLibrary'
import { Database } from '../../data/Database'
import { BehaviorCategory, BehaviorFactor } from '../../model/Models'
import { VisionService, OcrOutcome } from '../../service/VisionService'
import { SemanticParser, ParsedItem } from '../../service/SemanticParser'

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

  private runPhoto(): void {
    toast('选择一张低碳行为相关照片…')
    VisionService.recognizeFromGallery().then((o: OcrOutcome) => {
      if (!o.ok) {
        toast(o.msg)
        return
      }
      this.ocrText = o.text
      const r = SemanticParser.parse(o.text)
      this.ocrItems = r.items
      this.sheet = 'photo'
    })
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
    const total: number = this.ocrItems.length
    let done: number = 0
    for (const it of this.ocrItems) {
      Database.insertRecord(ctx, it.factorId, it.amount, '拍照', '').then(() => {
        done++
        if (done === total) {
          emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
          toast(`已从照片记录 ${total} 条行为!`)
          this.sheet = 'none'
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
    Database.insertRecord(ctx, 'E01', cur - last, '抄表', `读数 ${last}→${cur}`).then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      toast(`已记录节电 ${cur - last} 度(抄表)`)
      this.sheet = 'none'
    })
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
    })
  }

  build() {
    Stack() {
      Column() {
        // 标题 + AI 录入入口
        Column() {
          Text('记一笔').fontSize(22).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
          Text('选行为 → 填数量 → 自动核算减排量')
            .fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 2 })
          Row({ space: 8 }) {
            Text('📷 拍照识别')
              .fontSize(12)
              .fontColor(ZeroTheme.primary)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor(ZeroTheme.primaryLight)
              .borderRadius(16)
              .onClick(() => {
                this.runPhoto()
              })
            Text('🔍 电表抄表')
              .fontSize(12)
              .fontColor(ZeroTheme.primary)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor(ZeroTheme.primaryLight)
              .borderRadius(16)
              .onClick(() => {
                this.runMeter()
              })
            Blank()
            Text('端侧AI · 离线可用')
              .fontSize(9).fontColor(ZeroTheme.textSub)
          }
          .width('100%')
          .margin({ top: 10 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

        // 分类 chips
        Scroll() {
          Row({ space: 8 }) {
            ForEach(FactorLibrary.categories, (cat: BehaviorCategory) => {
              Text(`${cat.icon} ${cat.name}`)
                .fontSize(13)
                .fontColor(this.selectedCategory === cat.id ? ZeroTheme.textLight : ZeroTheme.textMain)
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .backgroundColor(this.selectedCategory === cat.id ? ZeroTheme.primary : ZeroTheme.cardBg)
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
                Text(FactorLibrary.sceneLabel(f.scene))
                  .fontSize(10)
                  .fontColor(ZeroTheme.primary)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor(ZeroTheme.primaryLight)
                  .borderRadius(6)

                Column() {
                  Text(f.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(ZeroTheme.textMain)
                  Text(f.tip).fontSize(10).fontColor(ZeroTheme.textSub).margin({ top: 3 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 10 })

                Column() {
                  Text(`${f.factor.toFixed(2)}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
                  Text(`kg CO₂e / ${f.unit}`).fontSize(9).fontColor(ZeroTheme.textSub)
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .padding(ZeroTheme.padM)
              .backgroundColor(ZeroTheme.cardBg)
              .borderRadius(ZeroTheme.radiusM)
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
      .backgroundColor(ZeroTheme.bg)

      // 录入面板(选中行为时弹出)
      if (this.selectedFactor !== null) {
        Column() {
          Column() {
            Row() {
              Text(`${FactorLibrary.categoryIcon(this.selectedFactor.categoryId)} ${this.selectedFactor.name}`)
                .fontSize(17).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
              Blank()
              Text('✕')
                .fontSize(18).fontColor(ZeroTheme.textSub)
                .padding(6)
                .onClick(() => {
                  this.selectedFactor = null
                })
            }.width('100%')

            Text(`口径:${this.selectedFactor.tip}`)
              .fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 6 })

            Row({ space: 8 }) {
              Button('−')
                .fontSize(18).width(44).height(44)
                .backgroundColor(ZeroTheme.bg).fontColor(ZeroTheme.textMain)
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
                .backgroundColor(ZeroTheme.bg)
                .onChange((value: string) => {
                  this.amountStr = value
                })
              Button('+')
                .fontSize(18).width(44).height(44)
                .backgroundColor(ZeroTheme.bg).fontColor(ZeroTheme.textMain)
                .onClick(() => {
                  const v: number = this.amountValue()
                  this.amountStr = `${Math.round(v + 1)}`
                })
              Text(this.selectedFactor.unit)
                .fontSize(14).fontColor(ZeroTheme.textMain).width(40)
            }
            .width('100%')
            .margin({ top: 14 })

            Row({ space: 8 }) {
              ForEach([1, 3, 5, 10], (q: number) => {
                Text(`${q}`)
                  .fontSize(13)
                  .fontColor(this.amountStr === `${q}` ? ZeroTheme.textLight : ZeroTheme.textMain)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .backgroundColor(this.amountStr === `${q}` ? ZeroTheme.primary : ZeroTheme.bg)
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
                .fontSize(14).fontWeight(FontWeight.Medium).fontColor(ZeroTheme.primary)
              Blank()
              Text(`+${Math.round(this.co2Preview() * 10)} 岛币`)
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.accent)
            }
            .width('100%')
            .padding(ZeroTheme.padM)
            .backgroundColor(ZeroTheme.primaryLight)
            .borderRadius(ZeroTheme.radiusM)
            .margin({ top: 14 })

            Button('保存并记录')
              .fontSize(15)
              .width('100%')
              .height(44)
              .backgroundColor(ZeroTheme.primary)
              .margin({ top: 14 })
              .onClick(() => {
                this.save()
              })
          }
          .alignItems(HorizontalAlign.Start)
          .padding(ZeroTheme.padL)
          .backgroundColor(ZeroTheme.cardBg)
          .borderRadius({ topLeft: ZeroTheme.radiusL, topRight: ZeroTheme.radiusL })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .backgroundColor('rgba(10,30,28,0.35)')
        .onClick(() => {
          this.selectedFactor = null
        })
      }

      // 拍照识别确认面板
      if (this.sheet === 'photo') {
        Column() {
          Column() {
            Row() {
              Text('📷 拍照识别结果').fontSize(17).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
              Blank()
              Text('✕').fontSize(18).fontColor(ZeroTheme.textSub)
                .onClick(() => {
                  this.sheet = 'none'
                })
            }.width('100%')

            Text(this.ocrText.length > 0 ? `照片文字:「${this.ocrText.substring(0, 60)}」` : '照片中未检出文字')
              .fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 6 })

            if (this.ocrItems.length > 0) {
              ForEach(this.ocrItems, (it: ParsedItem) => {
                Row() {
                  Text(it.icon).fontSize(15)
                  Text(`${it.name} × ${it.amount} ${it.unit}`)
                    .fontSize(13).fontColor(ZeroTheme.textMain).margin({ left: 8 })
                  Blank()
                  Text(`+${it.points} 币`).fontSize(12).fontColor(ZeroTheme.accent)
                }
                .width('100%')
                .padding({ top: 7, bottom: 7 })
              }, (it: ParsedItem) => it.factorId + it.amount)
            } else {
              Text('没识别出明确的低碳行为,建议改用手动录入')
                .fontSize(12).fontColor(ZeroTheme.danger).margin({ top: 8 })
            }

            Button(this.ocrItems.length > 0 ? `确认记录 ${this.ocrItems.length} 条` : '知道了')
              .fontSize(14)
              .width('100%')
              .height(42)
              .backgroundColor(this.ocrItems.length > 0 ? ZeroTheme.primary : ZeroTheme.bg)
              .fontColor(this.ocrItems.length > 0 ? ZeroTheme.textLight : ZeroTheme.textSub)
              .margin({ top: 12 })
              .onClick(() => {
                this.savePhotoItems()
              })
          }
          .alignItems(HorizontalAlign.Start)
          .padding(ZeroTheme.padL)
          .backgroundColor(ZeroTheme.cardBg)
          .borderRadius({ topLeft: ZeroTheme.radiusL, topRight: ZeroTheme.radiusL })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .backgroundColor('rgba(10,30,28,0.35)')
        .onClick(() => {
          this.sheet = 'none'
        })
      }

      // 电表抄表面板
      if (this.sheet === 'meter') {
        Column() {
          Column() {
            Row() {
              Text('🔍 电表抄表').fontSize(17).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
              Blank()
              Text('✕').fontSize(18).fontColor(ZeroTheme.textSub)
                .onClick(() => {
                  this.sheet = 'none'
                })
            }.width('100%')

            Text(this.meterDigits.length > 0
              ? `识别到数字:${this.meterDigits.join(' / ')}`
              : `照片文字:「${this.ocrText.substring(0, 40)}」(未检出数字,可手动填写)`)
              .fontSize(12).fontColor(ZeroTheme.textSub).margin({ top: 6 })

            if (this.meterDigits.length > 0) {
              Row({ space: 6 }) {
                Text('点选当前读数:').fontSize(11).fontColor(ZeroTheme.textSub)
                ForEach(this.meterDigits.slice(0, 4), (d: string) => {
                  Text(d)
                    .fontSize(12)
                    .fontColor(this.meterCurrent === d ? ZeroTheme.textLight : ZeroTheme.textMain)
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor(this.meterCurrent === d ? ZeroTheme.primary : ZeroTheme.bg)
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
              Text('当前读数').fontSize(12).fontColor(ZeroTheme.textSub)
              TextInput({ text: this.meterCurrent })
                .type(InputType.NUMBER_DECIMAL)
                .fontSize(14).height(38).layoutWeight(1)
                .textAlign(TextAlign.Center).backgroundColor(ZeroTheme.bg)
                .onChange((v: string) => {
                  this.meterCurrent = v
                })
            }
            .width('100%')
            .margin({ top: 10 })

            Row({ space: 8 }) {
              Text('上次读数').fontSize(12).fontColor(ZeroTheme.textSub)
              TextInput({ text: this.meterLast, placeholder: '如 3250' })
                .type(InputType.NUMBER_DECIMAL)
                .fontSize(14).height(38).layoutWeight(1)
                .textAlign(TextAlign.Center).backgroundColor(ZeroTheme.bg)
                .onChange((v: string) => {
                  this.meterLast = v
                })
            }
            .width('100%')
            .margin({ top: 8 })

            Row() {
              Text(`本次用电 ${((parseFloat(this.meterCurrent) || 0) - (parseFloat(this.meterLast) || 0)).toFixed(0)} 度`)
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
              Blank()
              Text(`≈ +${Math.round(((parseFloat(this.meterCurrent) || 0) - (parseFloat(this.meterLast) || 0)) * 0.57 * 10)} 岛币`)
                .fontSize(13).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.accent)
            }
            .width('100%')
            .padding(ZeroTheme.padM)
            .backgroundColor(ZeroTheme.primaryLight)
            .borderRadius(ZeroTheme.radiusM)
            .margin({ top: 12 })

            Button('确认记录节电')
              .fontSize(14)
              .width('100%')
              .height(42)
              .backgroundColor(ZeroTheme.primary)
              .margin({ top: 12 })
              .onClick(() => {
                this.saveMeter()
              })
          }
          .alignItems(HorizontalAlign.Start)
          .padding(ZeroTheme.padL)
          .backgroundColor(ZeroTheme.cardBg)
          .borderRadius({ topLeft: ZeroTheme.radiusL, topRight: ZeroTheme.radiusL })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .backgroundColor('rgba(10,30,28,0.35)')
        .onClick(() => {
          this.sheet = 'none'
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
