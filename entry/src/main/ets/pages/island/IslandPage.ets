import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { ISLAND_STAGES, IslandStage } from '../../model/Models'
import { Database, Summary } from '../../data/Database'
import { SemanticParser, ParsedItem } from '../../service/SemanticParser'
import { IslandScene } from '../../components/IslandScene'
import { HeroLifeLayer } from '../../components/HeroLifeLayer'

/** 首页「屿」:五阶段实景 Hero + 玻璃卡浮层 + 语义录入 + 生长仪式感 */
@Component
export struct IslandPage {
  @State ecoValue: number = 0
  @State points: number = 0
  @State streakDays: number = 0
  @State todayCo2: number = 0
  @State semanticInput: string = ''
  @State parsed: ParsedItem[] = []
  @State unmatchedNote: string = ''
  @State growPulse: number = 0
  @State gainVisible: boolean = false
  @State rippleOn: boolean = false
  @State gainText: string = ''
  private shownStage: number = 0
  private prevCo2: number = 0

  aboutToAppear(): void {
    emitter.on({ eventId: EVT_DATA_CHANGED }, () => {
      this.loadStats()
    })
    this.loadStats()
  }

  private async loadStats(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const s: Summary = await Database.summary(ctx)
    const days: number = await Database.streak(ctx)
    this.ecoValue = s.totalCo2
    this.points = s.totalPoints
    this.todayCo2 = s.todayCo2
    this.streakDays = days
    if (s.totalCo2 > this.prevCo2 && this.prevCo2 > 0) {
      this.playGrow(s.totalCo2 - this.prevCo2)
    }
    this.prevCo2 = s.totalCo2
  }

  /** 生长仪式感:全屏涟漪 + 增益浮字 */
  private playGrow(gain: number): void {
    this.gainText = `+${gain.toFixed(2)} kg`
    this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
      this.gainVisible = true
      this.rippleOn = true
    })
    this.growPulse++
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseIn }, () => {
        this.gainVisible = false
        this.rippleOn = false
      })
    }, 950)
  }

  /** 时辰问候 */
  private greeting(): string {
    const h: number = new Date().getHours()
    if (h >= 5 && h < 11) {
      return '早安,岛屿已醒来'
    }
    if (h < 17) {
      return '午后,给岛一点绿意'
    }
    if (h < 23) {
      return '暮色里,岛屿在呼吸'
    }
    return '夜深了,岛屿在做梦'
  }

  private handleParse(): void {
    if (this.semanticInput.trim().length === 0) {
      toast('先输入一句话描述你的低碳行为')
      return
    }
    const r = SemanticParser.parse(this.semanticInput)
    if (r.items.length === 0) {
      toast('没识别出低碳行为,试试:骑车3公里 / 光盘 / 节电2度')
      return
    }
    this.parsed = r.items
    this.unmatchedNote = r.unmatched.join('、')
  }

  private clearParse(): void {
    this.parsed = []
    this.unmatchedNote = ''
  }

  private parseTotalCo2(): number {
    let t: number = 0
    for (const it of this.parsed) {
      t += it.co2Kg
    }
    return t
  }

  private confirmParse(): void {
    if (this.parsed.length === 0) {
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    const total: number = this.parsed.length
    let done: number = 0
    for (const it of this.parsed) {
      Database.insertRecord(ctx, it.factorId, it.amount, '语义', '').then(() => {
        done++
        if (done === total) {
          emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
          toast(`已记录 ${total} 条,岛屿在生长!`)
          this.clearParse()
          this.semanticInput = ''
        }
      })
    }
  }

  private currentStage(): IslandStage {
    let stage: IslandStage = ISLAND_STAGES[0]
    for (let i = 0; i < ISLAND_STAGES.length; i++) {
      if (this.ecoValue >= ISLAND_STAGES[i].thresholdKg) {
        stage = ISLAND_STAGES[i]
      }
    }
    return stage
  }

  private stageIndex(): number {
    let idx: number = 0
    for (let i = 0; i < ISLAND_STAGES.length; i++) {
      if (this.ecoValue >= ISLAND_STAGES[i].thresholdKg) {
        idx = i
      }
    }
    return idx
  }

  private nextStage(): IslandStage | null {
    const cur: IslandStage = this.currentStage()
    for (let i = 0; i < ISLAND_STAGES.length; i++) {
      if (ISLAND_STAGES[i].name === cur.name && i < ISLAND_STAGES.length - 1) {
        return ISLAND_STAGES[i + 1]
      }
    }
    return null
  }

  private progressPercent(): number {
    const cur: IslandStage = this.currentStage()
    const next: IslandStage | null = this.nextStage()
    if (next === null) {
      return 100
    }
    const span: number = next.thresholdKg - cur.thresholdKg
    if (span <= 0) {
      return 100
    }
    return Math.min(100, (this.ecoValue - cur.thresholdKg) / span * 100)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ===== 岛屿主视觉(全屏 Canvas,五阶段进化+动画)=====
      IslandScene({ stage: this.stageIndex(), growPulse: this.growPulse })
        .width('100%')
        .height(430)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      // Hero 底部融合带(图 → 内容底色)
      Column()
        .width('100%')
        .height(140)
        .margin({ top: 300 })
        .linearGradient({
          angle: 180,
          colors: [['rgba(240,253,244,0)', 0], [ZeroTheme.bg, 0.75], [ZeroTheme.bg, 1]]
        })

      // 阶段徽标(hero 左下)
      Column() {
        Blank().height(298)
        Row() {
          Text(`${this.currentStage().name} · ${this.currentStage().desc}`)
            .fontSize(12)
            .fontColor(ZeroTheme.textLight)
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .backgroundColor('rgba(10,63,76,0.62)')
            .backdropBlur(BlurStyle.Thin)
            .borderRadius(999)
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ left: ZeroTheme.padL })
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)

      // 顶部品牌行(压在 Hero 天空区)
      Row() {
        Column() {
          Text('零屿 Zero Isle')
            .fontSize(21)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F3D2E')
            .shadow({ radius: 6, color: 'rgba(255,255,255,0.85)', offsetX: 0, offsetY: 0 })
          Text(this.greeting())
            .fontSize(11)
            .fontColor('#2E5A4C')
            .margin({ top: 2 })
            .shadow({ radius: 5, color: 'rgba(255,255,255,0.8)', offsetX: 0, offsetY: 0 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 40 })
      .hitTestBehavior(HitTestMode.None)

      // ===== 内容滚动层(玻璃卡,压 Hero 底缘)=====
      Scroll() {
        Column() {
          Blank().height(352)

          // 生态值玻璃卡(压 Hero 底缘)
          Column() {
            Row() {
              Text('生态值').fontSize(12).fontColor(ZeroTheme.textSub)
              Blank()
              Text(`${this.ecoValue.toFixed(1)} kg`)
                .fontSize(13).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
                .fontFamily(ZeroTheme.fontNum)
              this.nextText()
            }.width('100%')
            Progress({ value: this.progressPercent(), total: 100, type: ProgressType.Linear })
              .color(ZeroTheme.primary)
              .width('100%')
              .margin({ top: 6 })
          }
          .padding(ZeroTheme.padM)
          .backgroundColor('rgba(255,255,255,0.66)')
          .backdropBlur(BlurStyle.Thin)
          .borderRadius(ZeroTheme.radiusM)
          .border({ width: 1, color: 'rgba(255,255,255,0.95)' })

          // 今日概览三卡
          Row({ space: 10 }) {
            Column() {
              Text('今日减排').fontSize(11).fontColor(ZeroTheme.textSub)
              Row() {
                Text(this.todayCo2.toFixed(2))
                  .fontSize(22).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
                  .fontFamily(ZeroTheme.fontNum)
                Text(' kg').fontSize(11).fontColor(ZeroTheme.textSub).margin({ bottom: 4 })
              }.margin({ top: 4 })
            }
            .layoutWeight(1)
            .padding({ top: 12, bottom: 12 })
            .backgroundColor(ZeroTheme.card)
            .borderRadius(ZeroTheme.radiusM)

            Column() {
              Text('岛币').fontSize(11).fontColor(ZeroTheme.textSub)
              Row() {
                Text(`${this.points}`)
                  .fontSize(22).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.goldDeep)
                  .fontFamily(ZeroTheme.fontNum)
                Text(' 分').fontSize(11).fontColor(ZeroTheme.textSub).margin({ bottom: 4 })
              }.margin({ top: 4 })
            }
            .layoutWeight(1)
            .padding({ top: 12, bottom: 12 })
            .backgroundColor(ZeroTheme.card)
            .borderRadius(ZeroTheme.radiusM)

            Column() {
              Text('连续打卡').fontSize(11).fontColor(ZeroTheme.textSub)
              Row() {
                Text(`${this.streakDays}`)
                  .fontSize(22).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
                  .fontFamily(ZeroTheme.fontNum)
                Text(' 天').fontSize(11).fontColor(ZeroTheme.textSub).margin({ bottom: 4 })
              }.margin({ top: 4 })
            }
            .layoutWeight(1)
            .padding({ top: 12, bottom: 12 })
            .backgroundColor(ZeroTheme.card)
            .borderRadius(ZeroTheme.radiusM)
          }.width('100%').margin({ top: 10 })

          // 语义录入卡
          Column() {
            Text('今天做了什么?').fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
            Text('一句话,自动记录低碳行为').fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 2 })
            Row({ space: 8 }) {
              TextInput({ text: this.semanticInput, placeholder: '试试:骑车3公里,午餐光盘' })
                .fontSize(13)
                .height(40)
                .layoutWeight(1)
                .backgroundColor(ZeroTheme.bg)
                .onChange((value: string) => {
                  this.semanticInput = value
                })
              Button('解析')
                .fontSize(13)
                .height(40)
                .backgroundColor(ZeroTheme.primary)
                .onClick(() => {
                  this.handleParse()
                })
            }.width('100%').margin({ top: 10 })

            Row({ space: 8 }) {
              ForEach(['骑车3公里', '光盘', '节电2度', '回收5个瓶子'], (ex: string) => {
                Text(ex)
                  .fontSize(11)
                  .fontColor(ZeroTheme.primary)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor(ZeroTheme.bg)
                  .borderRadius(12)
                  .onClick(() => {
                    this.semanticInput = ex
                  })
              }, (ex: string) => ex)
            }.width('100%').margin({ top: 8 })
          }
          .alignItems(HorizontalAlign.Start)
          .padding(ZeroTheme.padM)
          .backgroundColor(ZeroTheme.card)
          .borderRadius(ZeroTheme.radiusM)
          .margin({ top: 10 })

          // 解析结果确认卡
          if (this.parsed.length > 0) {
            Column() {
              Row() {
                Text(`识别到 ${this.parsed.length} 项低碳行为`)
                  .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
                Blank()
                Text('✕')
                  .fontSize(16).fontColor(ZeroTheme.textSub)
                  .onClick(() => {
                    this.clearParse()
                  })
              }.width('100%')

              ForEach(this.parsed, (it: ParsedItem) => {
                Row() {
                  Text(it.icon).fontSize(16)
                  Text(`${it.name} × ${it.amount} ${it.unit}`)
                    .fontSize(13).fontColor(ZeroTheme.textMain).margin({ left: 8 })
                  Blank()
                  Text(`+${it.points} 币`)
                    .fontSize(12).fontColor(ZeroTheme.goldDeep)
                }
                .width('100%')
                .padding({ top: 8, bottom: 8 })
              }, (it: ParsedItem) => it.factorId + it.amount)

              if (this.unmatchedNote.length > 0) {
                Text(`未识别(已忽略):${this.unmatchedNote}`)
                  .fontSize(10).fontColor(ZeroTheme.textSub).margin({ top: 4 })
              }

              Row() {
                Text(`合计 ${this.parseTotalCo2().toFixed(2)} kg CO₂e`)
                  .fontSize(13).fontColor(ZeroTheme.primary)
                Blank()
                Button('确认记录')
                  .fontSize(14)
                  .height(38)
                  .backgroundColor(ZeroTheme.primary)
                  .onClick(() => {
                    this.confirmParse()
                  })
              }
              .width('100%')
              .margin({ top: 8 })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(ZeroTheme.padM)
            .backgroundColor(ZeroTheme.sandSoft)
            .borderRadius(ZeroTheme.radiusM)
            .border({ width: 1, color: ZeroTheme.sand })
            .margin({ top: 10, bottom: 20 })
          }

          if (this.parsed.length === 0) {
            Column().height(20).width('100%')
          }
        }
        .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .align(Alignment.Top)

      // 头像入口(最顶层,避免被滚动层空白区遮挡)
      Row() {
        Circle({ width: 38, height: 38 })
          .fill('rgba(255,255,255,0.72)')
          .backdropBlur(BlurStyle.Thin)
          .onClick(() => {
            router.pushUrl({ url: 'pages/mine/MinePage' })
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ right: ZeroTheme.padL, top: 40 })

      // 生长仪式感:涟漪(Hero 中心)
      if (this.rippleOn) {
        Circle()
          .width(210)
          .height(210)
          .fill('rgba(5,150,105,0.22)')
          .position({ x: '50%', y: '13%' })
          .markAnchor({ x: '50%', y: '50%' })
      }

      // 生长仪式感:增益浮字
      if (this.gainVisible) {
        Text(this.gainText)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(ZeroTheme.lifeDeep)
          .fontFamily(ZeroTheme.fontNum)
          .shadow({ radius: 8, color: 'rgba(255,255,255,0.9)', offsetX: 0, offsetY: 0 })
          .position({ x: '50%', y: '24%' })
          .markAnchor({ x: '50%', y: '50%' })
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -26 })))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZeroTheme.bg)
  }

  @Builder
  nextText() {
    if (this.nextStage() !== null) {
      Text(` / 距${(this.nextStage() as IslandStage).name}还差 ${(this.nextStage() as IslandStage).thresholdKg - this.ecoValue > 0 ? ((this.nextStage() as IslandStage).thresholdKg - this.ecoValue).toFixed(1) : '0'} kg`)
        .fontSize(11)
        .fontColor(ZeroTheme.textSub)
    } else {
      Text(' / 已满级').fontSize(11).fontColor(ZeroTheme.accent)
    }
  }
}
