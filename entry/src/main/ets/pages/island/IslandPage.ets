import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { emitter } from '@kit.BasicServicesKit'
import display from '@ohos.display'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { ISLAND_STAGES, IslandStage, STAGE_THEMES, StageTheme } from '../../model/Models'
import { Database, Summary } from '../../data/Database'
import { SemanticParser, ParsedItem } from '../../service/SemanticParser'
import { AdvisorService, Advice } from '../../service/AdvisorService'
import { AnimatedNumber } from '../../components/Charts'
import { IslandScene } from '../../components/IslandScene'

/** 首页「屿」:五阶段实景 Hero + 玻璃卡浮层 + 语义录入 + 生长仪式感 */
@Component
export struct IslandPage {
  @StorageProp('darkOn') darkOn: boolean = false
  @State ecoValue: number = 0
  @State points: number = 0
  @State streakDays: number = 0
  @State todayCo2: number = 0
  @State semanticInput: string = ''
  @State parsed: ParsedItem[] = []
  @State unmatchedNote: string = ''
  @State growPulse: number = 0
  @State gainVisible: boolean = false
  @State gainText: string = ''
  @State advices: Advice[] = []
  @State adviceIdx: number = 0
  // D7:Hero 高度按屏幕比例自适应(折叠屏/平板不再依赖固定 470 基准)
  @State heroH: number = 470
  @State fusionTop: number = 285
  @State badgeTop: number = 298
  @State contentTop: number = 336
  // D4:双波纹扩散
  @State rippleScale: number = 1
  @State rippleOpacity: number = 0
  @State ripple2Scale: number = 1
  @State ripple2Opacity: number = 0
  // D6:首次三步引导
  @State guideStep: number = -1
  private guideIcons: string[] = ['icons/ic_leaf.svg', 'icons/ic_rank.svg', 'icons/ic_coin.svg']
  private guideTitles: string[] = ['每一笔都是一片绿', '岛屿随你生长', '看板 · 岛币 · 权益']
  private guideDescs: string[] = [
    '骑车、光盘、节电…一句话或拍张照,低碳行为自动换算成减排量',
    '减排越多,岛屿从灰屿一路进化:青屿 → 绿屿 → 森屿 → 生态屿',
    '完成任务攒岛币,兑换徽章与低碳权益,还能和家人合并碳账本'
  ]
  private shownStage: number = 0
  private prevCo2: number = 0
  // P1-1: 统一持有所有 setTimeout 句柄,组件销毁时全部清理,避免回调操作已销毁实例
  private timers: number[] = []

  /** 包装 setTimeout,自动登记句柄以便销毁时清理 */
  private setT(fn: () => void, ms: number): void {
    const id: number = setTimeout(fn, ms)
    this.timers.push(id)
  }

  /** 数据变更回调(保存引用,退订时只移除本页订阅,避免误删其它页监听) */
  private readonly onDataChanged: () => void = () => {
    this.loadStats()
  }

  aboutToAppear(): void {
    emitter.on({ eventId: EVT_DATA_CHANGED }, this.onDataChanged)
    this.loadStats()
    try {
      const d: display.Display = display.getDefaultDisplaySync()
      const vh: number = d.height / d.densityPixels
      this.heroH = Math.min(560, Math.max(400, vh * 0.5))
      this.fusionTop = this.heroH * 0.606
      this.badgeTop = this.heroH * 0.635
      this.contentTop = this.heroH * 0.715
    } catch (err) {
      // 屏幕信息不可用时保持 470 基准
    }
    const ctx = getContext(this) as common.UIAbilityContext
    Database.kvGet(ctx, 'guided', '').then((v: string) => {
      if (v === '') {
        this.setT(() => {
          this.guideStep = 0
        }, 600)
      }
    })
  }

  private guideNext(): void {
    if (this.guideStep < this.guideTitles.length - 1) {
      this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
        this.guideStep++
      })
    } else {
      this.guideFinish()
    }
  }

  private guideFinish(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    Database.kvSet(ctx, 'guided', '1')
    this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseIn }, () => {
      this.guideStep = -1
    })
  }

  aboutToDisappear(): void {
    emitter.off(EVT_DATA_CHANGED, this.onDataChanged)
    for (const id of this.timers) {
      clearTimeout(id)
    }
    this.timers = []
  }

  private async loadStats(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const s: Summary = await Database.summary(ctx)
    const days: number = await Database.streak(ctx)
    const spent: number = await Database.spentSum(ctx)
    this.ecoValue = s.totalCo2
    // 展示「可用岛币」= 累计获得 - 已消耗,与岛币商城判定保持一致
    this.points = s.totalPoints - spent
    this.todayCo2 = s.todayCo2
    this.streakDays = days
    if (s.totalCo2 > this.prevCo2 && this.prevCo2 > 0) {
      this.playGrow(s.totalCo2 - this.prevCo2)
    }
    this.prevCo2 = s.totalCo2
    AdvisorService.advise(ctx).then((list: Advice[]) => {
      this.advices = list
      if (this.adviceIdx >= list.length) {
        this.adviceIdx = 0
      }
    })
  }

  /** 生长仪式感(D4):增益浮字 + 双波纹扩散 */
  private playGrow(gain: number): void {
    this.gainText = `+${gain.toFixed(2)} kg`
    this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
      this.gainVisible = true
    })
    this.growPulse++
    // 第一道波纹:瞬时复位后放大淡出
    this.rippleScale = 0.55
    this.rippleOpacity = 0.85
    this.getUIContext().animateTo({ duration: 60 }, () => {
      this.rippleScale = 0.62
    })
    this.setT(() => {
      this.getUIContext().animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
        this.rippleScale = 1.9
        this.rippleOpacity = 0
      })
    }, 60)
    // 第二道波纹:延迟 240ms 跟进,形成涟漪层次
    this.setT(() => {
      this.ripple2Scale = 0.55
      this.ripple2Opacity = 0.7
      this.getUIContext().animateTo({ duration: 60 }, () => {
        this.ripple2Scale = 0.62
      })
      this.setT(() => {
        this.getUIContext().animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
          this.ripple2Scale = 1.9
          this.ripple2Opacity = 0
        })
      }, 40)
    }, 240)
    this.setT(() => {
      this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseIn }, () => {
        this.gainVisible = false
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
    const items: ParsedItem[] = this.parsed
    const total: number = items.length
    let done: number = 0
    let ok: number = 0
    const finish = (): void => {
      if (ok > 0) {
        emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      }
      if (ok === total) {
        toast(`已记录 ${total} 条,岛屿在生长!`)
        this.clearParse()
        this.semanticInput = ''
      } else {
        toast(`成功 ${ok} 条,失败 ${total - ok} 条,失败项可重新解析录入`)
      }
    }
    for (const it of items) {
      Database.insertRecord(ctx, it.factorId, it.amount, '语义', '').then(() => {
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

  /** 当前岛屿的阶段主题(专属配色 / 标志性图标 / 定位标签 / 一句话文案) */
  private stageTheme(): StageTheme {
    const i: number = Math.max(0, Math.min(STAGE_THEMES.length - 1, this.stageIndex()))
    return STAGE_THEMES[i]
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
        .height(this.heroH)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      // 深色模式:白昼插画叠加入夜遮罩,与「墨绿松石夜」主题协调
      if (this.darkOn) {
        Column()
          .width('100%')
          .height(this.heroH)
          .backgroundColor('rgba(6,26,22,0.42)')
          .hitTestBehavior(HitTestMode.None)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      }

      // Hero 底部融合带(图 → 内容底色):渐变提前完成,避免海面深色透进统计卡区
      Column()
        .width('100%')
        .height(185)
        .margin({ top: this.fusionTop })
        .linearGradient({
          angle: 180,
          colors: [[$r('app.color.fusion_a'), 0], [$r('app.color.fusion_b'), 0.28], [$r('app.color.bg'), 0.52], [$r('app.color.bg'), 1]]
        })

      // 阶段徽标(hero 左下):紧凑单行——主题色图标 + 岛名 + 定位标签 + 阶段序号
      Column() {
        Blank().height(this.badgeTop)
        Row() {
          Row({ space: 6 }) {
            Stack() {
              Column()
                .width(18).height(18)
                .borderRadius(999)
                .backgroundColor(this.stageTheme().tint)
              Image($rawfile(`icons/${this.stageTheme().icon}.svg`))
                .width(11)
                .height(11)
                .fillColor(Color.White)
            }
            Text(this.currentStage().name)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_light'))
            Text(this.stageTheme().tag)
              .fontSize(9)
              .fontColor(this.stageTheme().tint)
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .backgroundColor('rgba(255,255,255,0.88)')
              .borderRadius(999)
            Text(`${this.stageIndex() + 1}/${ISLAND_STAGES.length}`)
              .fontSize(9)
              .fontColor($r('app.color.text_light'))
              .opacity(0.75)
          }
          .padding({ left: 7, right: 9, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.scrim_badge'))
          .backdropBlur(BlurStyle.Thin)
          .borderRadius(999)
          .border({ width: 1, color: 'rgba(255,255,255,0.14)' })
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
          Text(this.greeting())
            .fontSize(11)
            .fontColor('#2E5A4C')
            .margin({ top: 2 })
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
          Blank().height(this.contentTop)

          // 生态值玻璃卡(压 Hero 底缘)
          Column() {
            Row() {
              Text('生态值').fontSize(12).fontColor($r('app.color.text_sub'))
              Blank()
              Row() {
                AnimatedNumber({ value: this.ecoValue, digits: 1, numSize: 13, color: $r('app.color.primary') })
                Text(' kg').fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary')).fontFamily(ZeroTheme.fontNum)
              }
              this.nextText()
            }.width('100%')
            Progress({ value: this.progressPercent(), total: 100, type: ProgressType.Linear })
              .color($r('app.color.primary'))
              .width('100%')
              .margin({ top: 6 })
            // 当前岛屿的定位标签与个性文案(放在内容区,不遮挡 Hero 视野)
            Row({ space: 5 }) {
              Column()
                .width(5).height(5)
                .borderRadius(999)
                .backgroundColor(this.stageTheme().tint)
              Text(`${this.stageTheme().tag} · ${this.stageTheme().intro}`)
                .fontSize(10)
                .fontColor($r('app.color.text_sub'))
            }
            .margin({ top: 7 })
          }
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.glass'))
          .backdropBlur(BlurStyle.Thin)
          .borderRadius(ZeroTheme.radiusM)
          .border({ width: 1, color: $r('app.color.border_glass') })

          // 今日概览(单张玻璃卡:避免卡缝透出岛屿深色横带)
          Row() {
            Column() {
              Text('今日减排').fontSize(11).fontColor($r('app.color.text_sub'))
              Row() {
                AnimatedNumber({ value: this.todayCo2, digits: 2, numSize: 22, color: $r('app.color.primary') })
                Text(' kg').fontSize(11).fontColor($r('app.color.text_sub')).margin({ bottom: 4 })
              }.margin({ top: 4 })
            }
            .layoutWeight(1)

            Divider()
              .vertical(true)
              .strokeWidth(1)
              .height(30)
              .color($r('app.color.divider_primary'))

            Column() {
              Text('可用岛币').fontSize(11).fontColor($r('app.color.text_sub'))
              Row() {
                AnimatedNumber({ value: this.points, digits: 0, numSize: 22, color: $r('app.color.gold_deep') })
                Text(' 分').fontSize(11).fontColor($r('app.color.text_sub')).margin({ bottom: 4 })
              }.margin({ top: 4 })
            }
            .layoutWeight(1)

            Divider()
              .vertical(true)
              .strokeWidth(1)
              .height(30)
              .color($r('app.color.divider_primary'))

            Column() {
              Text('连续打卡').fontSize(11).fontColor($r('app.color.text_sub'))
              Row() {
                AnimatedNumber({ value: this.streakDays, digits: 0, numSize: 22, color: $r('app.color.primary') })
                Text(' 天').fontSize(11).fontColor($r('app.color.text_sub')).margin({ bottom: 4 })
              }.margin({ top: 4 })
            }
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .backgroundColor($r('app.color.glass'))
          .backdropBlur(BlurStyle.Thin)
          .borderRadius(ZeroTheme.radiusM)
          .border({ width: 1, color: $r('app.color.border_glass') })
          .shadow({ radius: 14, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 5 })
          .margin({ top: 10 })

          // 岛灵 Agent 入口横幅:紧凑单行,醒目且不遮挡上方岛屿插画
          Row({ space: 9 }) {
            Column() {
              Text('🧚').fontSize(14)
            }
            .width(30).height(30).borderRadius(15)
            .backgroundColor('rgba(14,94,111,0.12)')
            .justifyContent(FlexAlign.Center)

            Text('和岛灵聊聊')
              .fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_deep'))
            Text('一句话记账 · 查数 · 建议')
              .fontSize(10).fontColor($r('app.color.text_sub'))

            Blank()

            Text('›')
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .borderRadius(ZeroTheme.radiusM)
          .linearGradient({
            angle: 135,
            colors: [[$r('app.color.sky_top'), 0.0], [$r('app.color.primary_light'), 1.0]]
          })
          .border({ width: 1, color: 'rgba(14,94,111,0.20)' })
          .shadow({ radius: 10, color: $r('app.color.shadow_medium'), offsetX: 0, offsetY: 3 })
          .margin({ top: 10 })
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .accessibilityText('和岛灵聊聊,打开对话式碳账本管家')
          .onClick(() => {
            router.pushUrl({ url: 'pages/agent/AgentPage' })
          })

          // 语义录入卡
          Column() {
            Text('今天做了什么?').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            Text('一句话,自动记录低碳行为').fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 2 })
            Row({ space: 8 }) {
              TextInput({ text: this.semanticInput, placeholder: '试试:骑车3公里,午餐光盘' })
                .fontSize(13)
                .height(42)
                .layoutWeight(1)
                .backgroundColor($r('app.color.bg'))
                .borderRadius(ZeroTheme.radiusS)
                .padding({ left: 12, right: 12 })
                .placeholderColor($r('app.color.text_sub'))
                .caretColor($r('app.color.primary'))
                .onChange((value: string) => {
                  this.semanticInput = value
                })
              Button('解析')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .height(42)
                .backgroundColor($r('app.color.primary'))
                .borderRadius(ZeroTheme.radiusS)
                .clickEffect({ level: ClickEffectLevel.LIGHT })
                .onClick(() => {
                  this.handleParse()
                })
            }.width('100%').margin({ top: 10 })

            Row({ space: 8 }) {
              ForEach(['骑车3公里', '光盘', '节电2度', '回收5个瓶子'], (ex: string) => {
                Text(ex)
                  .fontSize(11)
                  .fontColor($r('app.color.primary'))
                  .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                  .backgroundColor($r('app.color.bg'))
                  .border({ width: 1, color: $r('app.color.primary_light') })
                  .borderRadius(ZeroTheme.radiusPill)
                  .clickEffect({ level: ClickEffectLevel.LIGHT })
                  .onClick(() => {
                    this.semanticInput = ex
                  })
              }, (ex: string) => ex)
            }.width('100%').margin({ top: 8 })
          }
          .alignItems(HorizontalAlign.Start)
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.card'))
          .borderRadius(ZeroTheme.radiusM)
          .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
          .margin({ top: 10 })

          // 解析结果确认卡(紧贴输入卡下方,确保解析后立即可见)
          if (this.parsed.length > 0) {
            Column() {
              Row() {
                Text(`识别到 ${this.parsed.length} 项低碳行为`)
                  .fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
                Blank()
                Text('✕')
                  .fontSize(16).fontColor($r('app.color.text_sub'))
                  .onClick(() => {
                    this.clearParse()
                  })
              }.width('100%')

              ForEach(this.parsed, (it: ParsedItem) => {
                Row() {
                  Text(it.icon).fontSize(16)
                  Text(`${it.name} × ${it.amount} ${it.unit}`)
                    .fontSize(13).fontColor($r('app.color.text_main')).margin({ left: 8 })
                  Blank()
                  Text(`+${it.points} 币`)
                    .fontSize(12).fontColor($r('app.color.gold_deep'))
                }
                .width('100%')
                .padding({ top: 8, bottom: 8 })
              }, (it: ParsedItem) => it.factorId + it.amount)

              if (this.unmatchedNote.length > 0) {
                Text(`未识别(已忽略):${this.unmatchedNote}`)
                  .fontSize(10).fontColor($r('app.color.text_sub')).margin({ top: 4 })
              }

              Row() {
                Text(`合计 ${this.parseTotalCo2().toFixed(2)} kg CO₂e`)
                  .fontSize(13).fontColor($r('app.color.primary'))
                Blank()
                Button('确认记录')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .height(ZeroTheme.btnHeightS)
                  .backgroundColor($r('app.color.primary'))
                  .borderRadius(ZeroTheme.radiusPill)
                  .clickEffect({ level: ClickEffectLevel.LIGHT })
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
            .backgroundColor($r('app.color.sand_soft'))
            .borderRadius(ZeroTheme.radiusM)
            .border({ width: 1, color: $r('app.color.sand') })
            .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
            .margin({ top: 10 })
          }

          // 岛灵建议(本地规则引擎,个性化智能服务)
          if (this.advices.length > 0) {
            Column({ space: 4 }) {
              Row({ space: 5 }) {
                Image($rawfile('icons/ic_leaf.svg'))
                  .width(15).height(15).fillColor($r('app.color.life'))
                Text('岛灵建议')
                  .fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.life_deep'))
                Blank()
                Text('对话 ›')
                  .fontSize(10).fontColor($r('app.color.primary'))
                  .margin({ right: 10 })
                  .onClick(() => {
                    router.pushUrl({ url: 'pages/agent/AgentPage' })
                  })
                Text('换一条 ›')
                  .fontSize(10).fontColor($r('app.color.text_sub'))
                  .onClick(() => {
                    this.adviceIdx = (this.adviceIdx + 1) % this.advices.length
                  })
              }
              .width('100%')

              Text(`${this.advices[this.adviceIdx % this.advices.length].icon} ${this.advices[this.adviceIdx % this.advices.length].title}`)
                .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                .margin({ top: 3 })
              Text(this.advices[this.adviceIdx % this.advices.length].detail)
                .fontSize(11).fontColor($r('app.color.text_sub')).lineHeight(17)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(ZeroTheme.padM)
            .backgroundColor($r('app.color.bg_deep'))
            .borderRadius(ZeroTheme.radiusM)
            .border({ width: 1, color: 'rgba(5,150,105,0.25)' })
            .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
            .margin({ top: 10 })
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
        Stack() {
          Column()
            .width(40).height(40)
            .borderRadius(999)
            .backgroundColor($r('app.color.brand_deep'))
          Image($rawfile('icons/ic_leaf.svg'))
            .width(20)
            .height(20)
            .fillColor(Color.White)
        }
        .width(44)
        .height(44)
        .border({ width: 2.5, color: $r('app.color.border_glass') })
        .borderRadius(22)
        .shadow({ radius: 10, color: 'rgba(10,63,76,0.35)', offsetY: 3 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/mine/MinePage' })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ right: ZeroTheme.padL, top: 40 })

      // 生长仪式感:双波纹扩散(D4,常驻树由透明度驱动)
      // 纯装饰层:HitTestMode.None 避免矩形命中区遮挡下层(如右上角头像)的点击
      Column()
        .width(210)
        .height(210)
        .borderRadius(999)
        .backgroundColor('rgba(5,150,105,0.20)')
        .scale({ x: this.rippleScale, y: this.rippleScale })
        .opacity(this.rippleOpacity)
        .position({ x: '50%', y: '13%' })
        .markAnchor({ x: '50%', y: '50%' })
        .hitTestBehavior(HitTestMode.None)

      Column()
        .width(210)
        .height(210)
        .borderRadius(999)
        .backgroundColor('rgba(110,231,183,0.16)')
        .scale({ x: this.ripple2Scale, y: this.ripple2Scale })
        .opacity(this.ripple2Opacity)
        .position({ x: '50%', y: '13%' })
        .markAnchor({ x: '50%', y: '50%' })
        .hitTestBehavior(HitTestMode.None)

      // 生长仪式感:增益浮字
      if (this.gainVisible) {
        Text(this.gainText)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.life_deep'))
          .fontFamily(ZeroTheme.fontNum)
          .shadow({ radius: 8, color: 'rgba(255,255,255,0.9)', offsetX: 0, offsetY: 0 })
          .position({ x: '50%', y: '24%' })
          .markAnchor({ x: '50%', y: '50%' })
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -26 })))
      }

      // 首次启动三步引导(D6)
      if (this.guideStep >= 0) {
        Column() {
          Column({ space: 12 }) {
            Column() {
              Image($rawfile(this.guideIcons[this.guideStep]))
                .width(30)
                .height(30)
                .fillColor(Color.White)
            }
            .justifyContent(FlexAlign.Center)
            .width(64)
            .height(64)
            .borderRadius(22)
            .backgroundColor($r('app.color.primary'))

            Text(this.guideTitles[this.guideStep])
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_main'))
            Text(this.guideDescs[this.guideStep])
              .fontSize(13)
              .fontColor($r('app.color.text_sub'))
              .lineHeight(20)
              .textAlign(TextAlign.Center)

            Row({ space: 6 }) {
              ForEach(this.guideTitles, (_t: string, i: number) => {
                Column()
                  .width(7).height(7)
                  .borderRadius(999)
                  .backgroundColor(i === this.guideStep ? $r('app.color.primary') : $r('app.color.hairline'))
                  .hitTestBehavior(HitTestMode.None)
              }, (i: number) => i.toString())
            }
            .margin({ top: 2 })

            Button(this.guideStep < this.guideTitles.length - 1 ? '下一步' : '开始低碳之旅')
              .fontSize(15)
              .width('64%')
              .height(42)
              .backgroundColor($r('app.color.primary'))
              .onClick(() => {
                this.guideNext()
              })
            Text('跳过')
              .fontSize(12)
              .fontColor($r('app.color.text_sub'))
              .onClick(() => {
                this.guideFinish()
              })
          }
          .alignItems(HorizontalAlign.Center)
          .width('100%')
          .padding({ left: 24, right: 24, top: 28, bottom: 22 })
          .backgroundColor($r('app.color.card'))
          .borderRadius(ZeroTheme.radiusL)
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.scrim_sheet'))
        .onClick(() => {
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
  }

  @Builder
  nextText() {
    if (this.nextStage() !== null) {
      Text(` / 距${(this.nextStage() as IslandStage).name}还差 ${(this.nextStage() as IslandStage).thresholdKg - this.ecoValue > 0 ? ((this.nextStage() as IslandStage).thresholdKg - this.ecoValue).toFixed(1) : '0'} kg`)
        .fontSize(11)
        .fontColor($r('app.color.text_sub'))
    } else {
      Text(' / 已满级').fontSize(11).fontColor($r('app.color.accent'))
    }
  }
}
