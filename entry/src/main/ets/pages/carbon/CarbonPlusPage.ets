import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { util } from '@kit.ArkTS'
import { picker, fileIo as fs } from '@kit.CoreFileKit'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { ZeroMotion } from '../../common/Motion'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { Database, Summary, PlatformAccount, Voucher } from '../../data/Database'
import { DistributedSync } from '../../service/DistributedSync'

interface Benefit {
  icon: string
  tint: string
  name: string
  cost: number
}

interface FamilyMember {
  name: string
  points: number
  co2: number
}

interface FamilyPack {
  type: string
  version: number
  /** 导出方设备标识:导入时据此判定是否自己的包 */
  device_id: string
  member: FamilyMember
}

/** 一条模拟接口调用记录(协议层留痕) */
interface ApiLogItem {
  time: string
  api: string
  req: string
  resp: string
}

const BENEFITS: Benefit[] = [
  { icon: 'ic_bike', tint: '#059669', name: '公交 5 元乘车券', cost: 100 },
  { icon: 'ic_bowl', tint: '#D96C5F', name: '咖啡 8 折券', cost: 150 },
  { icon: 'ic_bolt', tint: '#D97706', name: '地铁月票 9 折', cost: 300 }
]

/** 城市碳普惠平台(接口协议模拟层):积分同步 + 权益兑换 + 家庭碳积分合并 */
@Entry
@Component
struct CarbonPlusPage {
  @State available: number = 0
  @State synced: boolean = false
  @State syncing: boolean = false
  @State lastSyncText: string = ''
  @State myPoints: number = 0
  @State myCo2: number = 0
  @State myName: string = '我'
  @State familyMembers: FamilyMember[] = []
  @State familyPoints: number = 0
  @State familyCo2: number = 0
  @State apiLogs: ApiLogItem[] = []
  @State showApiLog: boolean = false
  // 平台碳积分账户(与岛币分账:1 kgCO2e = 1 碳积分)
  @State platformBal: number = 0
  @State platformEarned: number = 0
  @State platformSpent: number = 0
  @State pendingCo2: number = 0
  @State vouchers: Voucher[] = []
  // 超级终端分布式同步状态(P1-2 路线①:真实落地)
  @State distAvailable: boolean = false
  @State distDevices: number = 0
  @State distPoints: number = 0
  @State distCo2: number = 0
  @State distSyncing: boolean = false

  aboutToAppear(): void {
    this.refresh()
    // 同步状态持久化:重进页面不再"复位"
    const ctx = getContext(this) as common.UIAbilityContext
    Database.kvGet(ctx, 'carbonplus_last_sync', '').then((v: string) => {
      if (v !== '') {
        this.synced = true
        this.lastSyncText = v
      }
    })
    this.loadFamily(ctx)
    this.loadApiLogs(ctx)
    Database.getNickname(ctx).then((n: string) => {
      this.myName = n
    })
    // 初始化超级终端分布式同步(环境不支持时优雅降级)
    DistributedSync.init(ctx).then((ok: boolean) => {
      this.distAvailable = ok
      if (ok) {
        DistributedSync.onRemoteChange(() => {
          this.publishAndAggregate()
        })
        this.publishAndAggregate()
      }
    })
  }

  /** 把本机汇总发布到分布式库并汇总所有设备数据 */
  private async publishAndAggregate(): Promise<void> {
    if (!DistributedSync.isAvailable()) {
      return
    }
    await DistributedSync.pushLocal(this.myPoints, this.myCo2)
    const agg = await DistributedSync.aggregate()
    this.distDevices = agg.deviceCount
    this.distCo2 = agg.co2
    this.distPoints = agg.points
  }

  /** 手动触发超级终端同步 */
  private syncDist(): void {
    if (!DistributedSync.isAvailable() || this.distSyncing) {
      return
    }
    this.distSyncing = true
    DistributedSync.pushLocal(this.myPoints, this.myCo2)
    DistributedSync.syncNow()
    // 跨设备同步为异步网络过程,先基于本机已发布数据刷新一次聚合视图
    this.publishAndAggregate().then(() => {
      this.distSyncing = false
      toast('已触发超级终端同步')
    })
  }

  private refresh(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    const p1: Promise<Summary> = Database.summary(ctx)
    const p2: Promise<number> = Database.spentSum(ctx)
    Promise.all([p1, p2]).then((values) => {
      this.myPoints = values[0].totalPoints
      this.myCo2 = values[0].totalCo2
      this.available = values[0].totalPoints - values[1]
      this.computeFamilyTotals()
      this.publishAndAggregate()
      this.loadPlatform(ctx)
    })
  }

  /** 读取平台碳积分账户与券包 */
  private loadPlatform(ctx: common.UIAbilityContext): void {
    Database.platformAccount(ctx, this.myCo2).then((a: PlatformAccount) => {
      this.platformBal = a.balance
      this.platformEarned = a.earned
      this.platformSpent = a.spent
      this.pendingCo2 = a.pending
      Database.vouchers(ctx, 20).then((list: Voucher[]) => {
        this.vouchers = list
      })
    })
  }

  private dateOf(ms: number): string {
    const d = new Date(ms)
    const mm: string = (d.getMonth() + 1) < 10 ? '0' + (d.getMonth() + 1) : '' + (d.getMonth() + 1)
    const dd: string = d.getDate() < 10 ? '0' + d.getDate() : '' + d.getDate()
    return `${mm}-${dd}`
  }

  // ==================== 家庭碳积分合并 ====================

  private async loadFamily(ctx: common.UIAbilityContext): Promise<void> {
    try {
      const raw: string = await Database.kvGet(ctx, 'family_json', '')
      if (raw !== '') {
        const arr = JSON.parse(raw) as Array<FamilyMember>
        if (Array.isArray(arr)) {
          this.familyMembers = arr
          this.computeFamilyTotals()
        }
      }
    } catch (err) {
      // 数据损坏按空处理
    }
  }

  private computeFamilyTotals(): void {
    let pts: number = this.myPoints
    let co2: number = this.myCo2
    for (const m of this.familyMembers) {
      pts += m.points
      co2 += m.co2
    }
    this.familyPoints = pts
    this.familyCo2 = co2
  }

  private stamp(): string {
    const now = new Date()
    const mm: string = (now.getMonth() + 1) < 10 ? '0' + (now.getMonth() + 1) : '' + (now.getMonth() + 1)
    const dd: string = now.getDate() < 10 ? '0' + now.getDate() : '' + now.getDate()
    const hh: string = now.getHours() < 10 ? '0' + now.getHours() : '' + now.getHours()
    const mi: string = now.getMinutes() < 10 ? '0' + now.getMinutes() : '' + now.getMinutes()
    return `${mm}-${dd} ${hh}:${mi}`
  }

  private exportFamilyPack(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    Promise.all([Database.getDeviceId(ctx), Database.getNickname(ctx)]).then((ids: string[]) => {
      const opt: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
      opt.newFileNames = [`zeroisle-family-${Database.today()}.json`]
      new picker.DocumentViewPicker().save(opt).then((uris: Array<string>) => {
        if (uris.length === 0) {
          return
        }
        const pack: FamilyPack = {
          type: 'zeroisle_family',
          version: 2,
          device_id: ids[0],
          member: { name: ids[1], points: this.myPoints, co2: this.myCo2 }
        }
        const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
        fs.writeSync(file.fd, JSON.stringify(pack))
        fs.closeSync(file)
        toast(`「${ids[1]}」的积分包已导出,发给家人导入即可合并`)
      }).catch(() => {
        toast('已取消保存')
      })
    })
  }

  private importFamilyPack(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    const opt: picker.DocumentSelectOptions = new picker.DocumentSelectOptions()
    new picker.DocumentViewPicker().select(opt).then((uris: Array<string>) => {
      if (uris.length === 0) {
        return
      }
      const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_ONLY)
      const stat: fs.Stat = fs.statSync(file.fd)
      if (stat.size > 1024 * 1024) {
        fs.closeSync(file)
        toast('文件过大,不是有效的积分包')
        return
      }
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buf)
      fs.closeSync(file)
      let member: FamilyMember | null = null
      let packDevice: string = ''
      try {
        const text: string = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf))
        const parsed = JSON.parse(text) as Record<string, Object>
        if (typeof parsed['device_id'] === 'string') {
          packDevice = parsed['device_id'] as string
        }
        const m = parsed['member'] as FamilyMember
        if (m !== null && m !== undefined && typeof m.name === 'string' && m.name !== ''
          && m.points >= 0 && m.co2 >= 0) {
          member = m
        }
      } catch (err) {
        member = null
      }
      if (member === null) {
        toast('积分包格式不正确,请确认是「零屿」导出的文件')
        return
      }
      // 防自导入:按设备标识判定;旧版包(v1)与昵称撞车时按昵称兜底
      const target: FamilyMember = member
      Promise.all([Database.getDeviceId(ctx), Database.getNickname(ctx)]).then((ids: string[]) => {
        const myId: string = ids[0]
        const myName: string = ids[1]
        if (packDevice !== '' && packDevice === myId) {
          toast('这是你自己的积分包哦,请导入家人的文件')
          return
        }
        if (target.name === myName || target.name === '我(本机)') {
          toast(`昵称「${target.name}」与你自己重复,请让对方在设置里改个昵称再导出`)
          return
        }
        const merged: FamilyMember[] = this.familyMembers.filter((m: FamilyMember) => m.name !== target.name)
        merged.push({ name: target.name, points: target.points, co2: target.co2 })
        Database.kvSet(ctx, 'family_json', JSON.stringify(merged)).then(() => {
          this.familyMembers = merged
          this.computeFamilyTotals()
          toast(`已合并「${target.name}」的碳积分,家庭账本已更新`)
        })
      })
    }).catch(() => {
      toast('已取消导入')
    })
  }

  /** 生成演示家人(路演用;导入真实积分包按昵称覆盖) */
  private async addDemoFamily(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const demo: FamilyMember[] = [
      { name: '爸爸', points: 126, co2: 12.6 },
      { name: '妈妈', points: 94, co2: 9.4 }
    ]
    await Database.kvSet(ctx, 'family_json', JSON.stringify(demo))
    this.familyMembers = demo
    this.computeFamilyTotals()
    toast('已生成 2 位演示家人,导入真实积分包即可覆盖')
  }

  // ==================== 接口协议模拟层 ====================

  private appendApiLog(api: string, req: string, resp: string): void {
    const ctx = getContext(this) as common.UIAbilityContext
    Database.kvGet(ctx, 'cplus_api_log', '').then((raw: string) => {
      let list: ApiLogItem[] = []
      try {
        const arr = JSON.parse(raw) as Array<ApiLogItem>
        if (Array.isArray(arr)) {
          list = arr
        }
      } catch (err) {
        list = []
      }
      list.unshift({ time: this.stamp(), api: api, req: req, resp: resp })
      if (list.length > 8) {
        list = list.slice(0, 8)
      }
      Database.kvSet(ctx, 'cplus_api_log', JSON.stringify(list)).then(() => {
        this.apiLogs = list
      })
    })
  }

  private loadApiLogs(ctx: common.UIAbilityContext): void {
    Database.kvGet(ctx, 'cplus_api_log', '').then((raw: string) => {
      try {
        const arr = JSON.parse(raw) as Array<ApiLogItem>
        if (Array.isArray(arr)) {
          this.apiLogs = arr
        }
      } catch (err) {
        this.apiLogs = []
      }
    })
  }

  private level(): string {
    if (this.platformBal >= 800) {
      return '黄金减碳达人'
    }
    if (this.platformBal >= 400) {
      return '白银低碳先锋'
    }
    return '青铜环保新秀'
  }

  /** 上报本机新增减排 → 折算为平台碳积分(接口协议 v1.0;正式版仅需替换为 HTTP 客户端) */
  private syncPoints(): void {
    if (this.syncing) {
      return
    }
    this.syncing = true
    const reportCo2: number = this.pendingCo2
    setTimeout(() => {
      const ctx = getContext(this) as common.UIAbilityContext
      const stamp: string = this.stamp()
      Database.platformUpload(ctx, this.myCo2).then((gain: number) => {
        Database.kvSet(ctx, 'carbonplus_last_sync', stamp).then(() => {
          this.syncing = false
          this.synced = true
          this.lastSyncText = stamp
          this.appendApiLog('POST /v1/points/sync',
            `{"account":"local","co2":${reportCo2.toFixed(2)}}`,
            `{"code":0,"msg":"accepted","credits":${gain},"syncId":"ZPS-${Date.now() % 100000}"}`)
          if (gain > 0) {
            toast(`已上报 ${reportCo2.toFixed(2)} kg 减排,平台账户新增 ${gain} 碳积分`)
          } else {
            toast('账本已是最新,没有新增减排需要上报')
          }
          this.loadPlatform(ctx)
        })
      })
    }, 900)
  }

  /** 兑换平台权益:扣平台碳积分并发放权益凭证到券包 */
  private redeem(b: Benefit): void {
    if (this.platformBal < b.cost) {
      toast(`碳积分不足(还差 ${b.cost - this.platformBal} 分),先同步账本再兑换`)
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    const code: string = `ZP-${Database.today().split('-').join('')}-${1000 + (Date.now() % 9000)}`
    Database.platformRedeem(ctx, `碳普惠·${b.name}`, code, b.cost, this.myCo2).then((ok: boolean) => {
      if (!ok) {
        toast('碳积分不足')
        return
      }
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      this.appendApiLog('POST /v1/benefits/redeem',
        `{"item":"${b.name}","cost":${b.cost}}`,
        `{"code":0,"voucher":"${code}"}`)
      toast(`已兑换「${b.name}」,权益码 ${code} 已存入券包`)
      this.loadPlatform(ctx)
    })
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
        Text($r('app.string.title_carbon')).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
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
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_light'))
              Blank()
              Text('离线演示层')
                .fontSize(9).fontColor($r('app.color.text_light'))
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor('rgba(255,255,255,0.2)')
                .borderRadius(6)
            }.width('100%')

            Text(`${this.platformBal}`)
              .fontSize(42).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_light'))
              .fontFamily(ZeroTheme.fontNum)
              .margin({ top: 12 })
            Text('可用碳积分 · 1 kg 减排 = 1 碳积分')
              .fontSize(11).fontColor('rgba(255,255,255,0.8)').margin({ top: 2 })

            Row({ space: 16 }) {
              Column() {
                Text(`${this.platformEarned}`).fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_light'))
                Text('累计获得').fontSize(9).fontColor('rgba(255,255,255,0.7)').margin({ top: 2 })
              }.alignItems(HorizontalAlign.Start)
              Column() {
                Text(`${this.platformSpent}`).fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_light'))
                Text('已兑换').fontSize(9).fontColor('rgba(255,255,255,0.7)').margin({ top: 2 })
              }.alignItems(HorizontalAlign.Start)
              Column() {
                Text(`${this.pendingCo2.toFixed(1)} kg`).fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_light'))
                Text('待上报减排').fontSize(9).fontColor('rgba(255,255,255,0.7)').margin({ top: 2 })
              }.alignItems(HorizontalAlign.Start)
              Blank()
            }
            .width('100%')
            .margin({ top: 12 })

            Row() {
              Text(`当前等级:${this.level()}`)
                .fontSize(12).fontColor($r('app.color.text_light'))
              Blank()
              Button(this.syncing ? '同步中…' : this.synced ? '再次上报' : '同步账本到平台')
                .fontSize(12).height(32)
                .backgroundColor(this.syncing ? 'rgba(255,255,255,0.3)' : $r('app.color.accent'))
                .onClick(() => {
                  if (!this.syncing) {
                    this.syncPoints()
                  }
                })
            }
            .width('100%')
            .margin({ top: 14 })

            Text(this.synced ? `上次上报 ${this.lastSyncText} · 接口协议 v1.0(离线演示层)` : '尚未上报 · 接口协议 v1.0(离线演示层)')
              .fontSize(10)
              .fontColor('rgba(255,255,255,0.7)')
              .margin({ top: 8 })
            Text(`本机岛币 ${this.available} 分 · 与碳积分分账,不参与本页兑换`)
              .fontSize(10)
              .fontColor('rgba(255,255,255,0.7)')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padL)
          .linearGradient({
            angle: 135,
            colors: [[$r('app.color.primary_deep'), 0], [$r('app.color.primary'), 1]]
          })
          .borderRadius(ZeroTheme.radiusL)

          // 权益兑换
          Column() {
            Text('碳积分权益兑换').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            ForEach(BENEFITS, (b: Benefit) => {
              Row() {
                Column() {
                  Image($rawfile(`icons/${b.icon}.svg`))
                    .width(22).height(22).fillColor($r('app.color.text_light'))
                }
                .justifyContent(FlexAlign.Center)
                .width(40).height(40)
                .borderRadius(12)
                .backgroundColor(b.tint)
                Column() {
                  Text(b.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                  Text(`需 ${b.cost} 碳积分`).fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 3 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 12 })
                Button('兑换')
                  .fontSize(12).height(32)
                  .backgroundColor(this.platformBal >= b.cost ? $r('app.color.primary') : $r('app.color.bg'))
                  .fontColor(this.platformBal >= b.cost ? $r('app.color.text_light') : $r('app.color.text_sub'))
                  .onClick(() => {
                    this.redeem(b)
                  })
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .border({ width: { bottom: 1 }, color: $r('app.color.hairline') })
            }, (b: Benefit) => b.name)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(ZeroTheme.radiusM)
          .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
          .margin({ top: 12 })

          // 我的权益 · 券包(兑换凭证闭环)
          Column() {
            Row() {
              Text('我的权益 · 券包').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              Blank()
              Text(`${this.vouchers.length} 张`).fontSize(11).fontColor($r('app.color.text_sub'))
            }
            .width('100%')

            if (this.vouchers.length === 0) {
              Text('还没有权益凭证 —— 先「同步账本到平台」攒碳积分,兑换后的权益码会收在这里')
                .fontSize(11).fontColor($r('app.color.text_sub')).lineHeight(18).margin({ top: 8 })
            } else {
              ForEach(this.vouchers, (v: Voucher) => {
                Row() {
                  Column() {
                    Text('券').fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_light'))
                  }
                  .justifyContent(FlexAlign.Center)
                  .width(34).height(34)
                  .borderRadius(10)
                  .backgroundColor($r('app.color.accent'))
                  Column() {
                    Text(v.title)
                      .fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`权益码 ${v.code}`).fontSize(10).fontColor($r('app.color.text_sub')).margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  .margin({ left: 10 })
                  Column() {
                    Text(v.cost > 0 ? `-${v.cost}` : '岛币兑').fontSize(12).fontColor($r('app.color.gold_deep'))
                    Text(this.dateOf(v.createdAt)).fontSize(9).fontColor($r('app.color.text_sub')).margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%')
                .padding({ top: 9, bottom: 9 })
                .border({ width: { bottom: 1 }, color: $r('app.color.hairline') })
              }, (v: Voucher) => `${v.id}`)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(ZeroTheme.radiusM)
          .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
          .margin({ top: 12 })

          // 超级终端分布式同步(创新①真实落地:同账号多设备通过分布式 KV 库自动汇聚碳账本)
          Column() {
            Row() {
              Text('超级终端同步').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              Blank()
              if (this.distAvailable) {
                Text('分布式 KV 已接入')
                  .fontSize(9).fontColor($r('app.color.ok'))
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor($r('app.color.primary_light'))
                  .borderRadius(6)
              } else {
                Text('当前环境未启用')
                  .fontSize(9).fontColor($r('app.color.text_sub'))
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor($r('app.color.bg'))
                  .borderRadius(6)
              }
            }
            .width('100%')

            if (this.distAvailable) {
              Row() {
                Column() {
                  Text(`${this.distDevices}`)
                    .fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
                    .fontFamily(ZeroTheme.fontNum)
                  Text('已连接设备').fontSize(10).fontColor($r('app.color.text_sub')).margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Column() {
                  Text(`${this.distCo2.toFixed(1)} kg`)
                    .fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.life'))
                    .fontFamily(ZeroTheme.fontNum)
                  Text('跨设备合计减排').fontSize(10).fontColor($r('app.color.text_sub')).margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              .margin({ top: 12 })

              Button(this.distSyncing ? '同步中…' : '同步到超级终端')
                .fontSize(12).height(34).width('100%')
                .backgroundColor($r('app.color.primary'))
                .margin({ top: 12 })
                .onClick(() => {
                  this.syncDist()
                })

              Text('登录同一华为账号的多台设备(手机/平板)通过分布式 KV 库自动汇聚碳账本,本机录入实时同步到超级终端。')
                .fontSize(10).fontColor($r('app.color.text_sub')).lineHeight(16).margin({ top: 8 })
            } else {
              Text('当前运行环境未启用分布式能力,需在登录同一华为账号的超级终端设备上体验。本地账本与家庭合并功能不受影响。')
                .fontSize(10).fontColor($r('app.color.text_sub')).lineHeight(16).margin({ top: 8 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(ZeroTheme.radiusM)
          .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
          .margin({ top: 12 })

          // 家庭碳积分合并
          Column() {
            Row() {
              Text('家庭碳积分合并').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              Blank()
              Text('文件级合并')
                .fontSize(9).fontColor($r('app.color.primary'))
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor($r('app.color.primary_light'))
                .borderRadius(6)
            }
            .width('100%')

            Row() {
              Column() {
                Text(`${this.familyPoints}`)
                  .fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
                  .fontFamily(ZeroTheme.fontNum)
                Text('家庭总积分').fontSize(10).fontColor($r('app.color.text_sub')).margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Column() {
                Text(`${this.familyCo2.toFixed(1)} kg`)
                  .fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.life'))
                  .fontFamily(ZeroTheme.fontNum)
                Text('家庭总减排').fontSize(10).fontColor($r('app.color.text_sub')).margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.End)
            }
            .width('100%')
            .margin({ top: 12 })

            ForEach(this.familyMembers, (m: FamilyMember) => {
              Row() {
                Text('👨‍👩‍👧').fontSize(14)
                Text(m.name).fontSize(12).fontColor($r('app.color.text_main')).margin({ left: 8 })
                Blank()
                Text(`${m.points} 分 · ${m.co2.toFixed(1)} kg`)
                  .fontSize(11).fontColor($r('app.color.text_sub'))
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })
              .border({ width: { bottom: 1 }, color: $r('app.color.hairline') })
            }, (m: FamilyMember) => m.name + m.points.toString())

            Row() {
              Text(this.myName).fontSize(12).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary')).margin({ left: 22 })
              Blank()
              Text(`${this.myPoints} 分 · ${this.myCo2.toFixed(1)} kg`)
                .fontSize(11).fontColor($r('app.color.primary'))
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
            .margin({ top: this.familyMembers.length > 0 ? -1 : 0 })

            if (this.familyMembers.length === 0) {
              Button('生成演示家人(路演用)')
                .fontSize(11).height(30).width('100%')
                .backgroundColor($r('app.color.bg'))
                .fontColor($r('app.color.text_sub'))
                .margin({ top: 8 })
                .onClick(() => {
                  this.addDemoFamily()
                })
            }

            Row({ space: 10 }) {
              Button('导出我的积分包')
                .fontSize(11).layoutWeight(1).height(34)
                .backgroundColor($r('app.color.primary'))
                .onClick(() => {
                  this.exportFamilyPack()
                })
              Button('导入家人积分包')
                .fontSize(11).layoutWeight(1).height(34)
                .backgroundColor($r('app.color.sand'))
                .fontColor($r('app.color.text_main'))
                .onClick(() => {
                  this.importFamilyPack()
                })
            }
            .width('100%')
            .margin({ top: 10 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(ZeroTheme.radiusM)
          .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
          .margin({ top: 12 })

          // 接口调用日志(协议层留痕)
          Column() {
            Row() {
              Text('接口调用日志').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              Blank()
              Text(this.showApiLog ? '收起 ↑' : '展开 ↓')
                .fontSize(11).fontColor($r('app.color.primary'))
            }
            .width('100%')
            .onClick(() => {
              this.showApiLog = !this.showApiLog
            })

            if (this.showApiLog) {
              if (this.apiLogs.length === 0) {
                Text('暂无调用记录,同步积分或兑换权益后这里会留下协议日志')
                  .fontSize(10).fontColor($r('app.color.text_sub')).margin({ top: 8 })
              }
              ForEach(this.apiLogs, (l: ApiLogItem) => {
                Column({ space: 2 }) {
                  Row({ space: 8 }) {
                    Text(l.time)
                      .fontSize(9).fontColor($r('app.color.text_sub'))
                      .fontFamily(ZeroTheme.fontNum)
                    Text(l.api)
                      .fontSize(11).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
                      .fontFamily(ZeroTheme.fontNum)
                  }
                  Text(`→ ${l.req}`)
                    .fontSize(9).fontColor($r('app.color.text_sub'))
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`← ${l.resp}`)
                    .fontSize(9).fontColor($r('app.color.ok'))
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
                .padding({ top: 8, bottom: 8 })
                .border({ width: { bottom: 1 }, color: $r('app.color.hairline') })
              }, (l: ApiLogItem) => l.time + l.api)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(ZeroTheme.radiusM)
          .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
          .margin({ top: 12 })

          Text('说明:本页包含两类能力——① 超级终端同步:基于分布式 KV 库(distributedKVStore,同账号多设备自动汇聚),是创新拓展①「多设备数据同步」的真实落地,已完成真机双设备实测(同账号双端,一端记录、另一端自动汇聚合并);② 家庭碳积分合并:跨账号场景通过本地积分包交换实现(文件级合并)。城市碳普惠平台接口为本地模拟层(协议 v1.0:积分同步 / 权益兑换)。')
            .fontSize(10).fontColor($r('app.color.text_sub')).lineHeight(16).margin({ top: 12 })

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
