import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { EVT_DATA_CHANGED } from '../../common/Common'
import { Database, Summary } from '../../data/Database'
import { SPECIES, Species } from '../../model/GameConfig'
import { IslandScene } from '../../components/IslandScene'

/** 岛屿生态图鉴:随生态值解锁的物种收集 */
@Entry
@Component
struct DexPage {
  @State ecoValue: number = 0

  aboutToAppear(): void {
    emitter.on({ eventId: EVT_DATA_CHANGED }, () => {
      this.loadStats()
    })
    this.loadStats()
  }

  private async loadStats(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const s: Summary = await Database.summary(ctx)
    this.ecoValue = s.totalCo2
  }

  private stageIndex(): number {
    let idx: number = 0
    const stages: number[] = [0, 10, 50, 150, 400]
    for (let i = 0; i < stages.length; i++) {
      if (this.ecoValue >= stages[i]) {
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
          .fontColor(ZeroTheme.textMain)
          .onClick(() => {
            router.back()
          })
        Blank()
        Text('岛屿图鉴').fontSize(18).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
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
          .fontColor(ZeroTheme.textLight)
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
          .fontSize(12).fontColor(ZeroTheme.primary)
        Blank()
        Text(`生态值 ${this.ecoValue.toFixed(1)} kg`)
          .fontSize(12).fontColor(ZeroTheme.textSub)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
      .margin({ top: 10 })

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
                    .fontSize(10).fontColor(ZeroTheme.textLight)
                    .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                    .backgroundColor(ZeroTheme.ok)
                    .borderRadius(8)
                }
              }
              .width(56)
              .height(56)

              Text(this.ecoValue >= sp.threshold ? sp.name : '???')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.ecoValue >= sp.threshold ? ZeroTheme.textMain : ZeroTheme.textSub)
                .margin({ top: 6 })
              Text(this.ecoValue >= sp.threshold ? sp.desc : `累计 ${sp.threshold} kg 解锁`)
                .fontSize(9)
                .fontColor(ZeroTheme.textSub)
                .textAlign(TextAlign.Center)
                .margin({ top: 3 })
            }
            .width('100%')
            .padding({ top: 14, bottom: 12 })
            .backgroundColor(this.ecoValue >= sp.threshold ? ZeroTheme.cardBg : ZeroTheme.bg)
            .borderRadius(ZeroTheme.radiusM)
            .border({ width: 1, color: this.ecoValue >= sp.threshold ? ZeroTheme.primaryLight : '#E4ECEA' })
          }
        }, (sp: Species) => sp.name + this.ecoValue.toFixed(0))
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .layoutWeight(1)
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZeroTheme.bg)
  }
}
