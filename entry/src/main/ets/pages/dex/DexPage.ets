import { common } from '@kit.AbilityKit'
import { router, display } from '@kit.ArkUI'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { ZeroMotion } from '../../common/Motion'
import { EVT_DATA_CHANGED } from '../../common/Common'
import { Database, Summary } from '../../data/Database'
import { ISLAND_STAGES } from '../../model/Models'
import { SPECIES, Species } from '../../model/GameConfig'
import { IslandScene } from '../../components/IslandScene'

/** 岛屿生态图鉴:随生态值解锁的物种收集 */
@Entry
@Component
struct DexPage {
  @State ecoValue: number = 0
  @State gridCols: string = '1fr 1fr 1fr'

  /** 数据变更回调(保存引用,退订时只移除本页订阅) */
  private readonly onDataChanged: () => void = () => {
    this.loadStats()
  }

  aboutToAppear(): void {
    this.computeCols()
    emitter.on({ eventId: EVT_DATA_CHANGED }, this.onDataChanged)
    this.loadStats()
  }

  /** 响应式列数:手机 3 列 / 平板 4 列 / 大屏 6 列 */
  private computeCols(): void {
    const d: display.Display = display.getDefaultDisplaySync()
    const vp: number = px2vp(d.width)
    if (vp >= 900) {
      this.gridCols = '1fr 1fr 1fr 1fr 1fr 1fr'
    } else if (vp >= 600) {
      this.gridCols = '1fr 1fr 1fr 1fr'
    } else {
      this.gridCols = '1fr 1fr 1fr'
    }
  }

  aboutToDisappear(): void {
    emitter.off(EVT_DATA_CHANGED, this.onDataChanged)
  }

  private async loadStats(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const s: Summary = await Database.summary(ctx)
    this.ecoValue = s.totalCo2
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

  private unlockedCount(): number {
    let n: number = 0
    for (const sp of SPECIES) {
      if (this.ecoValue >= sp.threshold) {
        n++
      }
    }
    return n
  }

  build() {
    Column() {
      // 顶部
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor($r('app.color.text_main'))
          .onClick(() => {
            router.back()
          })
        Blank()
        Text($r('app.string.title_dex')).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Row().width(22)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      // 图鉴横幅:会动的岛屿(随生态阶段同步)
      Stack({ alignContent: Alignment.BottomStart }) {
        IslandScene({ stage: this.stageIndex() })
        Text(`生态屿 · ${this.unlockedCount()}/${SPECIES.length} 物种已栖息`)
          .fontSize(11)
          .fontColor($r('app.color.text_light'))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor('rgba(10,63,76,0.72)')
          .borderRadius(999)
          .margin({ left: 10, bottom: 10 })
      }
      .width('100%')
      .height(150)
      .borderRadius(ZeroTheme.radiusM)
      .clip(true)
      .margin({ top: 10 })

      // 进度条
      Row() {
        Text(`已解锁 ${this.unlockedCount()}/${SPECIES.length} 种`)
          .fontSize(12).fontColor($r('app.color.primary'))
        Blank()
        Text(`生态值 ${this.ecoValue.toFixed(1)} kg`)
          .fontSize(12).fontColor($r('app.color.text_sub'))
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
      .margin({ top: 10 })

      Row() {
        Progress({ value: this.unlockedCount(), total: SPECIES.length, type: ProgressType.Linear })
          .width('100%')
          .style({ strokeWidth: 6 })
          .color($r('app.color.primary'))
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
      .margin({ top: 8 })

      Grid() {
        ForEach(SPECIES, (sp: Species) => {
          GridItem() {
            Column() {
              Stack({ alignContent: Alignment.Center }) {
                Text(this.ecoValue >= sp.threshold ? sp.icon : '❓')
                  .fontSize(34)
                  .opacity(this.ecoValue >= sp.threshold ? 1 : 0.35)
                if (this.ecoValue >= sp.threshold) {
                  Text('✓')
                    .fontSize(10).fontColor($r('app.color.text_light'))
                    .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                    .backgroundColor($r('app.color.ok'))
                    .borderRadius(8)
                }
              }
              .width(56)
              .height(56)

              Text(this.ecoValue >= sp.threshold ? sp.name : '???')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.ecoValue >= sp.threshold ? $r('app.color.text_main') : $r('app.color.text_sub'))
                .margin({ top: 6 })
              Text(this.ecoValue >= sp.threshold ? sp.desc : `累计 ${sp.threshold} kg 解锁`)
                .fontSize(9)
                .fontColor($r('app.color.text_sub'))
                .textAlign(TextAlign.Center)
                .margin({ top: 3 })
            }
            .width('100%')
            .padding({ top: 14, bottom: 12 })
            .backgroundColor(this.ecoValue >= sp.threshold ? $r('app.color.card_bg') : $r('app.color.bg'))
            .borderRadius(ZeroTheme.radiusM)
            .border({ width: 1, color: this.ecoValue >= sp.threshold ? $r('app.color.primary_light') : '#E4ECEA' })
            .shadow(this.ecoValue >= sp.threshold
              ? { radius: 10, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 3 }
              : { radius: 0, color: 'rgba(0,0,0,0)', offsetX: 0, offsetY: 0 })
          }
        }, (sp: Species) => sp.name)
      }
      .columnsTemplate(this.gridCols)
      .columnsGap(10)
      .rowsGap(10)
      .layoutWeight(1)
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
  }

  pageTransition() {
    PageTransitionEnter({ duration: ZeroMotion.pageDurIn, curve: Curve.Friction })
      .opacity(0)
      .translate({ y: 16 })
    PageTransitionExit({ duration: ZeroMotion.pageDurOut, curve: Curve.Friction })
      .opacity(0)
  }
}
