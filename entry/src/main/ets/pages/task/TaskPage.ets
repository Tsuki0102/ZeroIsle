import { common } from '@kit.AbilityKit'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { Database } from '../../data/Database'
import { notificationManager } from '@kit.NotificationKit'
import { RingProgress } from '../../components/Charts'
import { DAILY_TASKS, WEEK_TASKS, BADGES, SHOP_ITEMS, TaskDef } from '../../model/GameConfig'

/** 任务行状态 */
export class TaskRow {
  id: string = ''
  icon: string = ''
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
  name: string = ''
  desc: string = ''
  cost: number = 0
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
    rows.push(r)
  }
  return rows
}

/** 激励页「营」:每日任务 + 本周挑战 + 徽章墙 + 岛币商城 */
@Component
export struct TaskPage {
  @State available: number = 0
  @State totalEarned: number = 0
  @State dailyRows: TaskRow[] = []
  @State weekRows: TaskRow[] = []
  @State badgeRows: BadgeRow[] = []
  @State shopRows: ShopRow[] = makeShopRows()

  aboutToAppear(): void {
    emitter.on({ eventId: EVT_DATA_CHANGED }, () => {
      this.loadAll()
    })
    this.loadAll()
  }

  private async loadAll(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const s = await Database.summary(ctx)
    const spent: number = await Database.spentSum(ctx)
    this.totalEarned = s.totalPoints
    this.available = s.totalPoints - spent

    const weekKey: string = Database.dateBefore(6)
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
    const key: string = isDaily ? Database.today() : Database.dateBefore(6)
    Database.claimReward(ctx, r.id, r.reward, key).then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      toast(`领取成功 +${r.reward} 岛币!`)
      this.loadAll()
    })
  }

  private goRecord(r: TaskRow): void {
    toast(`去「记」页记录「${r.name}」相关行为,进度实时更新`)
  }

  private doExchange(item: ShopRow): void {
    if (this.available < item.cost) {
      toast('岛币不足,先去完成任务赚岛币吧')
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    Database.exchange(ctx, item.name, item.cost).then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      toast(`已兑换「${item.name}」`)
      this.loadAll()
    })
  }

  /** 每日任务提醒(本地通知,通知点"智能服务"落地) */
  private enableDailyNotify(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    notificationManager.requestEnableNotification(ctx).then(() => {
      const request: notificationManager.NotificationRequest = {
        id: 20260912,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '零屿 · 低碳营地',
            text: '新的校园低碳任务已发布:光盘打卡 / 节能行动 / 绿色通勤,完成可赚岛币!'
          }
        }
      }
      notificationManager.publish(request).then(() => {
        toast('每日提醒已开启,记得来完成今天的任务哦')
      }).catch(() => {
        toast('通知发布失败,请检查通知设置')
      })
    }).catch(() => {
      toast('通知权限未开启,可在系统设置中打开')
    })
  }

  build() {
    Column() {
      // 标题 + 岛币卡
      Row() {
        Column() {
          Text('低碳营地').fontSize(22).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
          Text('校园挑战 · 岛币 · 徽章').fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 2 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        Button('🔔 任务提醒')
          .fontSize(12)
          .height(32)
          .backgroundColor(ZeroTheme.primaryLight)
          .fontColor(ZeroTheme.primary)
          .onClick(() => {
            this.enableDailyNotify()
          })
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      Row() {
        Column() {
          Text('可用岛币').fontSize(11).fontColor(ZeroTheme.textSub)
          Row() {
            Text('🪙').fontSize(20)
            Text(`${this.available}`)
              .fontSize(26).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.accent).margin({ left: 6 })
          }.margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Divider().strokeWidth(1).color(ZeroTheme.primaryLight).height(36).vertical(true)
        Column() {
          Text('累计获得').fontSize(11).fontColor(ZeroTheme.textSub)
          Text(`${this.totalEarned} 分`)
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary).margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.End)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(ZeroTheme.padM)
      .backgroundColor(ZeroTheme.cardBg)
      .borderRadius(ZeroTheme.radiusM)
      .margin({ top: 12 })

      List({ space: 10 }) {
        // 每日任务
        ListItem() {
          Text('每日任务 · 每天 0 点刷新')
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
            .padding({ top: 4 })
        }
        ForEach(this.dailyRows, (r: TaskRow) => {
          ListItem() {
            this.taskCard(r, true)
          }
        }, (r: TaskRow) => r.id + r.claimed.toString() + r.progress.toString())

        // 本周挑战
        ListItem() {
          Text('本周校园挑战')
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
            .padding({ top: 6 })
        }
        ForEach(this.weekRows, (r: TaskRow) => {
          ListItem() {
            this.taskCard(r, false)
          }
        }, (r: TaskRow) => r.id + r.claimed.toString() + r.progress.toString())

        // 徽章墙
        ListItem() {
          Text('徽章墙')
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
            .padding({ top: 6 })
        }
        ListItem() {
          Scroll() {
            Row({ space: 10 }) {
              ForEach(this.badgeRows, (b: BadgeRow) => {
                Column() {
                  Text(b.unlocked ? b.icon : '🔒').fontSize(30)
                  Text(b.name)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(b.unlocked ? ZeroTheme.textMain : ZeroTheme.textSub)
                    .margin({ top: 6 })
                  Text(b.desc)
                    .fontSize(9)
                    .fontColor(ZeroTheme.textSub)
                    .textAlign(TextAlign.Center)
                    .margin({ top: 3 })
                }
                .width(110)
                .padding({ top: 14, bottom: 12, left: 8, right: 8 })
                .backgroundColor(b.unlocked ? ZeroTheme.accentSoft : ZeroTheme.bg)
                .borderRadius(ZeroTheme.radiusM)
                .border({ width: 1, color: b.unlocked ? ZeroTheme.accent : '#E0E8E6' })
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
            Image($rawfile('shop_header.jpg'))
              .width('100%')
              .height(96)
              .objectFit(ImageFit.Cover)
              .borderRadius(ZeroTheme.radiusM)
              .margin({ top: 6 })
            Text('岛币商城')
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
              .margin({ top: 10 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }
        ForEach(this.shopRows, (item: ShopRow) => {
          ListItem() {
            Row() {
              Text(item.icon).fontSize(26)
              Column() {
                Text(item.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(ZeroTheme.textMain)
                Text(item.desc).fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 3 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 12 })

              Column() {
                Text(`🪙 ${item.cost}`).fontSize(13).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.accent)
                Button(this.available >= item.cost ? '兑换' : '岛币不足')
                  .fontSize(12)
                  .height(30)
                  .backgroundColor(this.available >= item.cost ? ZeroTheme.primary : ZeroTheme.bg)
                  .fontColor(this.available >= item.cost ? ZeroTheme.textLight : ZeroTheme.textSub)
                  .margin({ top: 4 })
                  .onClick(() => {
                    this.doExchange(item)
                  })
              }
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')
            .padding(ZeroTheme.padM)
            .backgroundColor(ZeroTheme.cardBg)
            .borderRadius(ZeroTheme.radiusM)
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
    .backgroundColor(ZeroTheme.bg)
  }

  @Builder
  taskCard(r: TaskRow, isDaily: boolean) {    Row() {
      Text(r.icon).fontSize(26)
      Column() {
        Row() {
          Text(r.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(ZeroTheme.textMain)
          Text(` +${r.reward} 岛币`)
            .fontSize(11).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.ok).margin({ left: 6 })
        }
        Text(r.desc).fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 3 })
        Row() {
          RingProgress({ value: r.progress, total: r.goal, color: r.done ? ZeroTheme.life : ZeroTheme.primary })
          Text(` ${r.progress}/${r.goal} ${r.unit}`)
            .fontSize(10).fontColor(ZeroTheme.textSub).margin({ left: 4 })
        }.margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })

      if (r.claimed) {
        Text('已领取')
          .fontSize(12).fontColor(ZeroTheme.textSub)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(ZeroTheme.bg)
          .borderRadius(14)
      } else if (r.done) {
        Button('领取')
          .fontSize(13)
          .height(34)
          .backgroundColor(ZeroTheme.accent)
          .onClick(() => {
            this.claim(r, isDaily)
          })
      } else {
        Button('去完成')
          .fontSize(12)
          .height(34)
          .backgroundColor(ZeroTheme.primaryLight)
          .fontColor(ZeroTheme.primary)
          .onClick(() => {
            this.goRecord(r)
          })
      }
    }
    .width('100%')
    .padding(ZeroTheme.padM)
    .backgroundColor(ZeroTheme.cardBg)
    .borderRadius(ZeroTheme.radiusM)
  }
}
