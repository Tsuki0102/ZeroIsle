import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { Database } from '../../data/Database'

interface Benefit {
  icon: string
  name: string
  cost: number
}

const BENEFITS: Benefit[] = [
  { icon: '🚌', name: '公交 5 元乘车券', cost: 100 },
  { icon: '☕', name: '咖啡 8 折券', cost: 150 },
  { icon: '🚇', name: '地铁月票 9 折', cost: 300 }
]

/** 城市碳普惠平台(模拟对接):积分同步 + 权益兑换 */
@Entry
@Component
struct CarbonPlusPage {
  @State available: number = 0
  @State synced: boolean = false
  @State syncing: boolean = false

  aboutToAppear(): void {
    this.refresh()
  }

  private refresh(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    const p1 = Database.summary(ctx)
    const p2 = Database.spentSum(ctx)
    Promise.all([p1, p2]).then((values) => {
      this.available = values[0].totalPoints - values[1]
    })
  }

  private level(): string {
    if (this.available >= 800) {
      return '黄金减碳达人'
    }
    if (this.available >= 400) {
      return '白银低碳先锋'
    }
    return '青铜环保新秀'
  }

  private syncPoints(): void {
    this.syncing = true
    setTimeout(() => {
      this.syncing = false
      this.synced = true
      toast('积分已同步至碳普惠平台(模拟)')
    }, 900)
  }

  private redeem(b: Benefit): void {
    if (this.available < b.cost) {
      toast('积分不足')
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    Database.exchange(ctx, `碳普惠·${b.name}`, b.cost).then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      toast(`已兑换「${b.name}」,权益码已发放(模拟)`)
      this.refresh()
    })
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22).fontColor(ZeroTheme.textMain)
          .onClick(() => {
            router.back()
          })
        Blank()
        Text('碳普惠平台').fontSize(18).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
        Blank()
        Row().width(22)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      Scroll() {
        Column() {
          // 平台账户卡
          Column() {
            Row() {
              Text('豫碳分 · 城市碳普惠平台')
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textLight)
              Blank()
              Text('模拟对接')
                .fontSize(9).fontColor(ZeroTheme.textLight)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor('rgba(255,255,255,0.2)')
                .borderRadius(6)
            }.width('100%')

            Text(`${this.available}`)
              .fontSize(42).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textLight)
              .margin({ top: 12 })
            Text('已同步碳积分')
              .fontSize(11).fontColor('rgba(255,255,255,0.8)').margin({ top: 2 })

            Row() {
              Text(`当前等级:${this.level()}`)
                .fontSize(12).fontColor(ZeroTheme.textLight)
              Blank()
              Button(this.syncing ? '同步中…' : this.synced ? '已同步 ✓' : '同步积分到平台')
                .fontSize(12).height(32)
                .backgroundColor(this.syncing ? 'rgba(255,255,255,0.3)' : ZeroTheme.accent)
                .onClick(() => {
                  if (!this.syncing) {
                    this.syncPoints()
                  }
                })
            }
            .width('100%')
            .margin({ top: 16 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padL)
          .linearGradient({
            angle: 135,
            colors: [[ZeroTheme.primaryDeep, 0], [ZeroTheme.primary, 1]]
          })
          .borderRadius(ZeroTheme.radiusL)

          // 权益兑换
          Column() {
            Text('碳积分权益兑换').fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
            ForEach(BENEFITS, (b: Benefit) => {
              Row() {
                Text(b.icon).fontSize(24)
                Column() {
                  Text(b.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor(ZeroTheme.textMain)
                  Text(`需 ${b.cost} 碳积分`).fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 3 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 12 })
                Button('兑换')
                  .fontSize(12).height(32)
                  .backgroundColor(this.available >= b.cost ? ZeroTheme.primary : ZeroTheme.bg)
                  .fontColor(this.available >= b.cost ? ZeroTheme.textLight : ZeroTheme.textSub)
                  .onClick(() => {
                    this.redeem(b)
                  })
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .border({ width: { bottom: 1 }, color: '#EFF4F2' })
            }, (b: Benefit) => b.name)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor(ZeroTheme.cardBg)
          .borderRadius(ZeroTheme.radiusM)
          .margin({ top: 12 })

          Text('说明:本页为城市碳普惠平台接口的本地模拟实现,正式版本可通过市碳普惠开放平台 API 接入真实权益体系,积分账本与本机完全一致。')
            .fontSize(10).fontColor(ZeroTheme.textSub).lineHeight(16).margin({ top: 12 })

          Column().height(20)
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
    .backgroundColor(ZeroTheme.bg)
  }
}
