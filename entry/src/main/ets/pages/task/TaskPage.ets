import { common } from '@kit.AbilityKit'
import { emitter } from '@kit.BasicServicesKit'
import { router } from '@kit.ArkUI'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED, EVT_GO_RECORD } from '../../common/Common'
import { Database } from '../../data/Database'
import { notificationManager } from '@kit.NotificationKit'
import { ReminderService } from '../../service/ReminderService'
import { CertificateService, TreeCert } from '../../service/CertificateService'
import { RingProgress } from '../../components/Charts'
import { CampStrip } from '../../components/MiniScenes'
import { DAILY_TASKS, WEEK_TASKS, BADGES, SHOP_ITEMS, TaskDef } from '../../model/GameConfig'

/** 任务行状态 */
export class TaskRow {
  id: string = ''
  icon: string = ''
  tint: string = '#0E5E6F'
  name: string = ''
  desc: string = ''
  reward: number = 0
  goal: number = 1
  unit: string = ''
  progress: number = 0
  claimed: boolean = false
  done: boolean = false
}

/** 徽章行状态 */
export class BadgeRow {
  icon: string = ''
  name: string = ''
  desc: string = ''
  unlocked: boolean = false
}

/** 商品行状态 */
export class ShopRow {
  id: string = ''
  icon: string = ''
  tint: string = '#D97706'
  name: string = ''
  desc: string = ''
  cost: number = 0
  route: string = ''
}

function makeShopRows(): ShopRow[] {
  const rows: ShopRow[] = []
  for (const s of SHOP_ITEMS) {
    const r = new ShopRow()
    r.id = s.id
    r.icon = s.icon
    r.name = s.name
    r.desc = s.desc
    r.cost = s.cost
    r.tint = s.tint
    r.route = s.route
    rows.push(r)
  }
  return rows
}

/** 激励页「营」:每日任务 + 本周挑战 + 徽章墙 + 岛币商城 */
@Component
export struct TaskPage {
  @State available: number = 0
  @State totalEarned: number = 0
  @State totalCo2: number = 0
  @State dailyRows: TaskRow[] = []
  @State weekRows: TaskRow[] = []
  @State badgeRows: BadgeRow[] = []
  @State shopRows: ShopRow[] = makeShopRows()

  /** 数据变更回调(保存引用,退订时只移除本页订阅,避免误删其它页监听) */
  private readonly onDataChanged: () => void = () => {
    this.loadAll()
  }

  aboutToAppear(): void {
    emitter.on({ eventId: EVT_DATA_CHANGED }, this.onDataChanged)
    this.loadAll()
  }

  aboutToDisappear(): void {
    emitter.off(EVT_DATA_CHANGED, this.onDataChanged)
  }

  private async loadAll(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const s = await Database.summary(ctx)
    const spent: number = await Database.spentSum(ctx)
    this.totalEarned = s.totalPoints
    this.available = s.totalPoints - spent
    this.totalCo2 = s.totalCo2

    const weekKey: string = Database.weekMonday()
    this.dailyRows = await this.loadTasks(DAILY_TASKS, ctx, Database.today())
    this.weekRows = await this.loadTasks(WEEK_TASKS, ctx, weekKey)

    // 徽章实时判定
    const streak: number = await Database.streak(ctx)
    const cats = await Database.categoryStats(ctx)
    const byCat: Map<string, number> = new Map()
    for (const c of cats) {
      byCat.set(c.categoryId, c.co2)
    }
    const rows: BadgeRow[] = []
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
      const r = new BadgeRow()
      r.icon = b.icon
      r.name = b.name
      r.desc = b.desc
      r.unlocked = value >= b.threshold
      rows.push(r)
    }
    this.badgeRows = rows
  }

  private async loadTasks(defs: TaskDef[], ctx: common.UIAbilityContext, periodKey: string): Promise<TaskRow[]> {
    const rows: TaskRow[] = []
    for (const t of defs) {
      const prog: number = await Database.taskProgress(ctx, t.check)
      const claimed: boolean = await Database.hasClaimed(ctx, t.id, periodKey)
      const r = new TaskRow()
      r.id = t.id
      r.icon = t.icon
      r.tint = t.tint
      r.name = t.name
      r.desc = t.desc
      r.reward = t.reward
      r.goal = t.goal
      r.unit = t.unit
      r.progress = Math.min(prog, t.goal)
      r.claimed = claimed
      r.done = prog >= t.goal
      rows.push(r)
    }
    return rows
  }

  private claim(r: TaskRow, isDaily: boolean): void {
    if (r.claimed || !r.done) {
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    const key: string = isDaily ? Database.today() : Database.weekMonday()
    Database.claimReward(ctx, r.id, r.reward, key).then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      toast(`领取成功 +${r.reward} 岛币!`)
      this.loadAll()
    })
  }

  private goRecord(r: TaskRow): void {
    emitter.emit({ eventId: EVT_GO_RECORD }, {})
    toast(`已切到「记」页,完成「${r.name}」相关行为即可领币`)
  }

  private doExchange(item: ShopRow): void {
    if (this.available < item.cost) {
      toast('岛币不足,先去完成任务赚岛币吧')
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    if (item.id === 's_tree') {
      // 植树证书唯一持有:已有证书时不再扣币,引导查看,防重复兑换
      CertificateService.list(ctx).then((certs: TreeCert[]) => {
        if (certs.length > 0) {
          toast('已持有植树证书,可在「我的」-「我的植树证书」查看')
          return
        }
        Database.exchange(ctx, item.name, item.cost).then(() => {
          emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
          CertificateService.issue(ctx, this.totalCo2).then((cert: TreeCert) => {
            toast(`已兑换「${item.name}」,证书编号 ${cert.serial}`)
            this.loadAll()
            router.pushUrl({ url: item.route, params: { serial: cert.serial } })
          })
        })
      })
      return
    }
    Database.exchange(ctx, item.name, item.cost).then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      if (item.id === 's_coupon') {
        // 岛币 → 碳普惠平台券:跨体系积分互通,权益码直接落到平台券包(不再只是跳页)
        const code: string = `ZP-${Database.today().split('-').join('')}-${1000 + (Date.now() % 9000)}`
        Database.addVoucher(ctx, '碳普惠·平台通用权益券', code, 0).then(() => {
          toast(`已兑换「${item.name}」,权益码 ${code} 已存入碳普惠券包`)
          this.loadAll()
          router.pushUrl({ url: item.route })
        })
      } else if (item.id === 's_badge') {
        // 兑换限定徽章卡:标记已激活并跳转徽章墙
        Database.kvSet(ctx, 'badge_card', '1').then(() => {
          toast(`已兑换「${item.name}」,已收入你的徽章墙`)
          this.loadAll()
          router.pushUrl({ url: item.route })
        })
      } else {
        toast(`已兑换「${item.name}」`)
        this.loadAll()
        if (item.route !== '') {
          router.pushUrl({ url: item.route })
        }
      }
    })
  }

  /** 每日低碳提醒:系统级定时提醒(每天 19:30,重启后仍生效) */
  private enableDailyNotify(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    notificationManager.requestEnableNotification(ctx).then(async () => {
      const msg: string = await ReminderService.enableDaily()
      toast(msg)
    }).catch(() => {
      toast('通知权限未开启,可在系统设置中打开')
    })
  }

  build() {
    Column() {
      // 标题 + 岛币卡
      Row() {
        Text('低碳营地')
          .fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .layoutWeight(1)

        Button() {
          Row({ space: 5 }) {
            Image($rawfile('icons/ic_bell.svg')).width(14).height(14).fillColor($r('app.color.primary'))
            Text('任务提醒').fontSize(12)
          }
        }
        .fontSize(12)
        .height(32)
        .backgroundColor($r('app.color.primary_light'))
        .fontColor($r('app.color.primary'))
        .onClick(() => {
          this.enableDailyNotify()
        })
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      List({ space: 10 }) {
        ListItem() {
        // 营地篝火动画场景条 + 玻璃数据牌
        Stack({ alignContent: Alignment.BottomStart }) {
          CampStrip()
          Row({ space: 8 }) {
            Text(`可用岛币 ${this.available} 分`)
              .fontSize(12).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              .fontFamily(ZeroTheme.fontNum)
            Text(`累计获得 ${this.totalEarned} 分`)
              .fontSize(10).fontColor($r('app.color.text_sub'))
          }
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor('rgba(255,255,255,0.8)')
          .borderRadius(999)
          .margin({ left: 12, bottom: 10 })
        }
        .width('100%')
        .height(128)
        .borderRadius(ZeroTheme.radiusL)
        .clip(true)
        .margin({ top: 12 })

        }
        // 每日任务
        ListItem() {
          Row({ space: 6 }) {
            Image($rawfile('icons/ic_calc.svg')).width(16).height(16).fillColor($r('app.color.primary'))
            Text('每日任务 · 每天 0 点刷新')
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              .padding({ top: 4 })
          }
        }
        ForEach(this.dailyRows, (r: TaskRow) => {
          ListItem() {
            this.taskCard(r, true)
          }
        }, (r: TaskRow) => r.id + r.claimed.toString() + r.progress.toString())

        // 本周挑战
        ListItem() {
          Row({ space: 6 }) {
            Image($rawfile('icons/ic_fire.svg')).width(16).height(16).fillColor($r('app.color.gold_deep'))
            Text('本周校园挑战 · 周一 0 点刷新')
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              .padding({ top: 6 })
          }
        }
        ForEach(this.weekRows, (r: TaskRow) => {
          ListItem() {
            this.taskCard(r, false)
          }
        }, (r: TaskRow) => r.id + r.claimed.toString() + r.progress.toString())

        // 徽章墙
        ListItem() {
          Row({ space: 6 }) {
            Image($rawfile('icons/ic_rank.svg')).width(16).height(16).fillColor($r('app.color.primary'))
            Text('徽章墙')
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              .padding({ top: 6 })
          }
        }
        ListItem() {
          Scroll() {
            Row({ space: 10 }) {
              ForEach(this.badgeRows, (b: BadgeRow) => {
                Column() {
                  Image($rawfile(`icons/${b.unlocked ? b.icon : 'ic_lock'}.svg`))
                    .width(30)
                    .height(30)
                    .fillColor(b.unlocked ? $r('app.color.gold_deep') : $r('app.color.text_sub'))
                    .opacity(b.unlocked ? 1 : 0.55)
                  Text(b.name)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(b.unlocked ? $r('app.color.text_main') : $r('app.color.text_sub'))
                    .margin({ top: 6 })
                  Text(b.desc)
                    .fontSize(10)
                    .fontColor($r('app.color.text_sub'))
                    .textAlign(TextAlign.Center)
                    .margin({ top: 3 })
                }
                .width(110)
                .padding({ top: 14, bottom: 12, left: 8, right: 8 })
                .backgroundColor(b.unlocked ? $r('app.color.accent_soft') : $r('app.color.bg'))
                .borderRadius(ZeroTheme.radiusM)
                .border({ width: 1, color: b.unlocked ? $r('app.color.accent') : $r('app.color.hairline') })
              }, (b: BadgeRow) => b.name + b.unlocked.toString())
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }

        // 岛币商城
        ListItem() {
          Column() {
            Row() {
              Column({ space: 3 }) {
                Text('岛币商城').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
                Text('攒币兑权益,让每一次坚持被看见').fontSize(10).fontColor('rgba(255,255,255,0.88)')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Image($rawfile('icons/ic_coin.svg'))
                .width(30).height(30).fillColor(Color.White)
                .opacity(0.92)
            }
            .width('100%')
            .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
            .height(88)
            .linearGradient({ angle: 135, colors: [[$r('app.color.gold_deep'), 0], [$r('app.color.sand'), 1]] })
            .borderRadius(ZeroTheme.radiusM)
            .margin({ top: 6 })
            Text('岛币商城')
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              .margin({ top: 10 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }
        ForEach(this.shopRows, (item: ShopRow) => {
          ListItem() {
            Row() {
              Column() {
                Image($rawfile(`icons/${item.icon}.svg`))
                  .width(24).height(24).fillColor(item.tint)
              }
              .justifyContent(FlexAlign.Center)
              .width(40).height(40)
              .borderRadius(12)
              .backgroundColor($r('app.color.bg'))
              Column() {
                Text(item.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                Text(item.desc).fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 3 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 12 })

              Column() {
                Text(`${item.cost}`).fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent'))
                Button(this.available >= item.cost ? '兑换' : '岛币不足')
                  .fontSize(12)
                  .height(30)
                  .backgroundColor(this.available >= item.cost ? $r('app.color.primary') : $r('app.color.bg'))
                  .fontColor(this.available >= item.cost ? $r('app.color.text_light') : $r('app.color.text_sub'))
                  .margin({ top: 4 })
                  .onClick(() => {
                    this.doExchange(item)
                  })
              }
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')
            .padding(ZeroTheme.padM)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(ZeroTheme.radiusM)
            .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
            .margin({ bottom: 20 })
          }
        }, (item: ShopRow) => item.id + (this.available >= item.cost).toString())
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 8, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: 720 })
    .backgroundColor($r('app.color.bg'))
  }

  @Builder
  taskCard(r: TaskRow, isDaily: boolean) {    Row() {
      Column() {
        Image($rawfile(`icons/${r.icon}.svg`))
          .width(22).height(22).fillColor($r('app.color.text_light'))
      }
      .justifyContent(FlexAlign.Center)
      .width(40).height(40)
      .borderRadius(13)
      .backgroundColor(r.tint)
      Column() {
        Row() {
          Text(r.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
          Text(` +${r.reward} 岛币`)
            .fontSize(11).fontWeight(FontWeight.Bold).fontColor($r('app.color.ok')).margin({ left: 6 })
        }
        Text(r.desc).fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 3 })
        Row() {
          RingProgress({ value: r.progress, total: r.goal, done: r.done })
          Text(` ${r.progress}/${r.goal} ${r.unit}`)
            .fontSize(10).fontColor($r('app.color.text_sub')).margin({ left: 4 })
        }.margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      if (r.claimed) {
        Text('已领取')
          .fontSize(12).fontColor($r('app.color.text_sub'))
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor($r('app.color.bg'))
          .borderRadius(14)
      } else if (r.done) {
        Button('领取')
          .fontSize(13)
          .height(34)
          .backgroundColor($r('app.color.accent'))
          .onClick(() => {
            this.claim(r, isDaily)
          })
      } else {
        Button('去完成')
          .fontSize(12)
          .height(34)
          .backgroundColor($r('app.color.primary_light'))
          .fontColor($r('app.color.primary'))
          .onClick(() => {
            this.goRecord(r)
          })
      }
    }
    .width('100%')
    .padding(ZeroTheme.padM)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(ZeroTheme.radiusM)
    .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
  }
}
