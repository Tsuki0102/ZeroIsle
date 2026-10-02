import { common } from '@kit.AbilityKit'
import { router, display } from '@kit.ArkUI'
import { ZeroTheme } from '../../common/Theme'
import { ZeroMotion } from '../../common/Motion'
import { Database, Summary } from '../../data/Database'
import { BADGES } from '../../model/GameConfig'
import { Medal, OrnateDivider, CollectibleStyle } from '../../components/Collectibles'

/** 徽章行状态 */
class BadgeItem {
  icon: string = ''
  name: string = ''
  desc: string = ''
  unlocked: boolean = false
}

/**
 * 我的徽章:收藏级勋章墙(随低碳行为实时解锁) + 限定徽章卡(商城内购身份徽章)。
 * 视觉与植树证书共用「祖母绿 × 赤金」收藏品体系(components/Collectibles)。
 */
@Entry
@Component
struct BadgePage {
  @State items: BadgeItem[] = []
  @State unlockedCount: number = 0
  @State totalCo2: number = 0
  @State cardOwned: boolean = false
  @State gridCols: string = '1fr 1fr'

  aboutToAppear(): void {
    this.computeCols()
    this.load()
  }

  /** 响应式列数:手机 2 列 / 平板 3 列 / 大屏 4 列 */
  private computeCols(): void {
    const d: display.Display = display.getDefaultDisplaySync()
    const vp: number = px2vp(d.width)
    if (vp >= 900) {
      this.gridCols = '1fr 1fr 1fr 1fr'
    } else if (vp >= 600) {
      this.gridCols = '1fr 1fr 1fr'
    } else {
      this.gridCols = '1fr 1fr'
    }
  }

  private async load(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const s: Summary = await Database.summary(ctx)
    const streak: number = await Database.streak(ctx)
    const cats = await Database.categoryStats(ctx)
    const byCat: Map<string, number> = new Map()
    for (const c of cats) {
      byCat.set(c.categoryId, c.co2)
    }
    const list: BadgeItem[] = []
    let n: number = 0
    for (const b of BADGES) {
      let value: number = 0
      if (b.metric === 'co2') {
        value = s.totalCo2
      } else if (b.metric === 'streak') {
        value = streak
      } else if (b.metric === 'points') {
        value = s.totalPoints
      } else if (b.metric.startsWith('cat:')) {
        value = byCat.get(b.metric.substring(4)) ?? 0
      }
      const it = new BadgeItem()
      it.icon = b.icon
      it.name = b.name
      it.desc = b.desc
      it.unlocked = value >= b.threshold
      if (it.unlocked) {
        n++
      }
      list.push(it)
    }
    this.items = list
    this.unlockedCount = n
    this.totalCo2 = s.totalCo2
    this.cardOwned = (await Database.kvGet(ctx, 'badge_card', '')) === '1'
  }

  /** 概览展示最高已解锁徽章(未解锁任何徽章时用叶片占位) */
  private heroIcon(): string {
    let icon: string = 'ic_leaf'
    for (const b of this.items) {
      if (b.unlocked) {
        icon = b.icon
      }
    }
    return icon
  }

  private pct(): number {
    return this.items.length === 0 ? 0 : Math.round(this.unlockedCount / BADGES.length * 100)
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22).fontColor($r('app.color.text_main'))
          .onClick(() => {
            router.back()
          })
        Blank()
        Text('我的徽章').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Row().width(22)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      Scroll() {
        Column() {
          // ===== 概览 Hero =====
          Column() {
            Row() {
              Medal({ medalIcon: this.heroIcon(), unlocked: this.unlockedCount > 0, medalSize: 76 })
              Column() {
                Text('徽章收藏 · COLLECTION')
                  .fontSize(10).letterSpacing(2).fontColor('rgba(251,240,206,0.92)')
                Row() {
                  Text(`${this.unlockedCount}`)
                    .fontSize(30).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').fontFamily(ZeroTheme.fontNum)
                  Text(`/ ${BADGES.length}`)
                    .fontSize(13).fontColor('rgba(255,255,255,0.8)').margin({ left: 3 })
                }
                .alignItems(VerticalAlign.Bottom)
                .margin({ top: 2 })
                Text(`累计碳减排 ${this.totalCo2.toFixed(1)} kgCO₂e`)
                  .fontSize(11).fontColor('rgba(255,255,255,0.86)').margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 16 })
            }
            .width('100%')

            // 收集进度
            Stack({ alignContent: Alignment.Start }) {
              Column().width('100%').height(6).borderRadius(3).backgroundColor('rgba(255,255,255,0.22)')
              Column()
                .width(`${this.pct()}%`)
                .height(6)
                .borderRadius(3)
                .linearGradient({ angle: 90, colors: [[CollectibleStyle.goldSheen, 0], [CollectibleStyle.gold, 1]] })
            }
            .width('100%')
            .height(6)
            .margin({ top: 16 })
          }
          .width('100%')
          .padding(ZeroTheme.padL)
          .linearGradient({ angle: 135, colors: [[CollectibleStyle.emeraldRoyal, 0], [CollectibleStyle.emeraldDeep, 1]] })
          .borderRadius(ZeroTheme.radiusL)
          .shadow({ radius: 16, color: 'rgba(10,60,72,0.28)', offsetY: 6 })
          .alignItems(HorizontalAlign.Start)

          // ===== 限定徽章卡 =====
          Row() {
            Medal({ medalIcon: 'ic_rank', unlocked: this.cardOwned, medalSize: 62 })
            Column() {
              Text('限定徽章卡')
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor(CollectibleStyle.ink)
              Text(this.cardOwned ? '已激活 · 你的专属身份徽章' : '尚未获得 · 可在「低碳营地」以岛币兑换')
                .fontSize(11).fontColor(CollectibleStyle.inkSoft).lineHeight(16).margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 14 })
            if (this.cardOwned) {
              Text('已激活')
                .fontSize(11).fontColor('#FFFFFF')
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(CollectibleStyle.goldDeep)
                .borderRadius(999)
            }
          }
          .width('100%')
          .padding(ZeroTheme.padM)
          .linearGradient({ angle: 150, colors: [[CollectibleStyle.cream, 0], [CollectibleStyle.creamDeep, 1]] })
          .borderRadius(ZeroTheme.radiusM)
          .border({ width: 1.5, color: this.cardOwned ? CollectibleStyle.goldLine : CollectibleStyle.goldLineSoft })
          .shadow({ radius: 10, color: 'rgba(140,106,30,0.14)', offsetY: 4 })
          .margin({ top: 14 })

          // ===== 徽章墙 =====
          Row() {
            Text('徽章墙').fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            Blank()
            Text(`${this.unlockedCount}/${BADGES.length} 已解锁`).fontSize(11).fontColor($r('app.color.text_sub'))
          }
          .width('100%')
          .margin({ top: 24 })

          Row() {
            OrnateDivider({ dividerWidth: 160 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 8 })

          Grid() {
            ForEach(this.items, (b: BadgeItem) => {
              GridItem() {
                Column() {
                  Medal({ medalIcon: b.icon, unlocked: b.unlocked, medalSize: 54 })
                  Text(b.name)
                    .fontSize(13).fontWeight(FontWeight.Medium)
                    .fontColor(b.unlocked ? CollectibleStyle.ink : $r('app.color.text_sub'))
                    .margin({ top: 12 })
                  Text(b.desc)
                    .fontSize(10)
                    .fontColor(b.unlocked ? CollectibleStyle.inkSoft : $r('app.color.text_sub'))
                    .textAlign(TextAlign.Center)
                    .lineHeight(14)
                    .margin({ top: 4 })
                  Text(b.unlocked ? '已解锁' : '待解锁')
                    .fontSize(9).fontWeight(FontWeight.Medium)
                    .fontColor(b.unlocked ? CollectibleStyle.goldDeep : $r('app.color.text_sub'))
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .backgroundColor(b.unlocked ? 'rgba(217,178,92,0.18)' : 'rgba(0,0,0,0.05)')
                    .borderRadius(999)
                    .margin({ top: 8 })
                }
                .width('100%')
                .padding({ top: 18, bottom: 16, left: 8, right: 8 })
                .linearGradient({
                  angle: 160,
                  colors: b.unlocked
                    ? [[CollectibleStyle.cream, 0], [CollectibleStyle.creamDeep, 1]]
                    : [[$r('app.color.bg'), 0], [$r('app.color.bg'), 1]]
                })
                .borderRadius(ZeroTheme.radiusM)
                .border({ width: 1, color: b.unlocked ? CollectibleStyle.goldLineSoft : $r('app.color.hairline') })
                .shadow(b.unlocked
                  ? { radius: 10, color: 'rgba(140,106,30,0.16)', offsetY: 4 }
                  : { radius: 0, color: 'rgba(0,0,0,0)', offsetY: 0 })
              }
            }, (b: BadgeItem) => b.name + b.unlocked.toString())
          }
          .columnsTemplate(this.gridCols)
          .columnsGap(12)
          .rowsGap(12)
          .width('100%')
          .margin({ top: 14, bottom: 24 })
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
