import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { util } from '@kit.ArkTS'
import { picker, fileIo as fs } from '@kit.CoreFileKit'
import { ZeroTheme } from '../../common/Theme'
import { ZeroMotion } from '../../common/Motion'
import { toast } from '../../common/Common'
import { Database, DailyPoint } from '../../data/Database'

interface RankRow {
  name: string
  co2: number
  me: boolean
}

interface MateEntry {
  name: string
  co2: number
  /** 导出方设备标识(旧数据包/演示数据可缺省) */
  device_id?: string
}

class PackEntry {
  name: string = ''
  co2: number = 0
  device_id: string = ''
}

class WeekPackData {
  type: string = 'weekpack'
  /** 导出方设备标识:导入时据此判定是否自己的包 */
  device_id: string = ''
  entries: PackEntry[] = []
}

/** 宿舍碳排周榜:领奖台 + 本机真实数据 + 舍友数据包导入合并(全程本地) */
@Entry
@Component
struct WeekRankPage {
  @State rows: RankRow[] = []
  @State myWeek: number = 0
  @State hasMates: boolean = false

  aboutToAppear(): void {
    this.load()
  }

  private async load(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const list: DailyPoint[] = await Database.dailySeries(ctx, 7)
    let sum: number = 0
    for (const d of list) {
      sum += d.co2
    }
    this.myWeek = sum
    const mates: MateEntry[] = await this.loadMates(ctx)
    this.hasMates = mates.length > 0
    const myName: string = await Database.getNickname(ctx)
    const rows: RankRow[] = []
    for (const m of mates) {
      rows.push({ name: m.name, co2: m.co2, me: false })
    }
    rows.push({ name: myName, co2: sum, me: true })
    rows.sort((a: RankRow, b: RankRow) => b.co2 - a.co2)
    this.rows = rows
  }

  private async loadMates(ctx: common.UIAbilityContext): Promise<MateEntry[]> {
    try {
      const raw: string = await Database.kvGet(ctx, 'mates_json', '')
      if (raw !== '') {
        const arr = JSON.parse(raw) as Array<MateEntry>
        if (Array.isArray(arr)) {
          return arr
        }
      }
    } catch (err) {
      // 本地数据损坏时按无舍友处理
    }
    return []
  }

  /** 生成演示对手(写入本地 kv,导入真实数据包即可覆盖) */
  private async addDemoMates(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const demo: MateEntry[] = [
      { name: '阿绿', co2: 6.8 },
      { name: '小碳', co2: 4.2 },
      { name: '屿邻', co2: 2.9 }
    ]
    await this.saveMates(ctx, demo)
    await this.load()
    toast('已生成 3 位演示对手,导入真实数据包即可覆盖')
  }

  private async saveMates(ctx: common.UIAbilityContext, mates: MateEntry[]): Promise<void> {
    await Database.kvSet(ctx, 'mates_json', JSON.stringify(mates))
  }

  /** 导入舍友数据包(JSON),合并去重 */
  private importPack(): void {
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
        toast('文件过大,不是有效的周数据包')
        return
      }
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buf)
      fs.closeSync(file)
      let entries: MateEntry[] = []
      try {
        const text: string = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf))
        const parsed = JSON.parse(text) as Record<string, Object>
        const list = parsed['entries'] as Array<MateEntry>
        if (!Array.isArray(list)) {
          toast('数据包格式不正确')
          return
        }
        entries = list
      } catch (err) {
        toast('数据包解析失败,请确认是「零屿」导出的周数据包')
        return
      }
      this.loadMates(ctx).then(async (existing: MateEntry[]) => {
        const myId: string = await Database.getDeviceId(ctx)
        const myName: string = await Database.getNickname(ctx)
        // 先剔除可能残留的本机行(旧版数据按昵称兜底),再按昵称合并去重
        const merged: MateEntry[] = existing.filter((m: MateEntry) => m.name !== myName && m.name !== '我(本机)')
        let mergedCount: number = 0
        for (const e of entries) {
          const isSelf: boolean = (e.device_id !== undefined && e.device_id !== '' && e.device_id === myId)
            || e.name === myName || e.name === '我(本机)'
          if (!isSelf && e.name !== '' && e.co2 >= 0) {
            const dup: MateEntry[] = merged.filter((m: MateEntry) => m.name === e.name)
            if (dup.length === 0) {
              merged.push({ name: e.name, co2: e.co2 })
            } else {
              dup[0].co2 = e.co2
            }
            mergedCount++
          }
        }
        await this.saveMates(ctx, merged)
        this.load()
        toast(mergedCount > 0 ? `已合并 ${mergedCount} 位舍友数据,榜单已更新` : '数据包里没有新的舍友数据')
      })
    }).catch(() => {
      toast('已取消导入')
    })
  }

  /** 导出我的周数据包 */
  private exportPack(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    Promise.all([Database.getDeviceId(ctx), Database.getNickname(ctx)]).then((ids: string[]) => {
      const opt: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
      opt.newFileNames = [`zeroisle-week-${Date.now()}.json`]
      new picker.DocumentViewPicker().save(opt).then((uris: Array<string>) => {
        if (uris.length === 0) {
          return
        }
        const pack = new WeekPackData()
        pack.device_id = ids[0]
        const e = new PackEntry()
        e.name = ids[1]
        e.co2 = this.myWeek
        e.device_id = ids[0]
        pack.entries.push(e)
        const data: string = JSON.stringify(pack)
        const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
        fs.writeSync(file.fd, data)
        fs.closeSync(file)
        toast(`「${ids[1]}」的周数据包已导出,发给舍友即可合并榜单`)
      }).catch(() => {
        toast('已取消导出')
      })
    })
  }

  /** 领奖台立柱:idx 为 rows 下标,内部读 @State,参数只传常量 */
  @Builder
  podiumCol(idx: number, rank: number, color: ResourceColor, h: number, big: boolean) {
    Column({ space: 5 }) {
      if (this.rows.length > idx) {
        Column()
          .width(22).height(22)
          .borderRadius(999)
          .backgroundColor(color)
          .opacity(0.95)
          .margin({ bottom: 3 })
          .hitTestBehavior(HitTestMode.None)
        Text(this.rows[idx].name)
          .fontSize(10)
          .maxLines(1)
          .fontWeight(this.rows[idx].me ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.rows[idx].me ? $r('app.color.primary') : $r('app.color.text_main'))
        Text(`${this.rows[idx].co2.toFixed(1)} kg`)
          .fontSize(big ? 16 : 12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.rows[idx].me ? $r('app.color.primary') : $r('app.color.text_main'))
        Column() {
          Text(`${rank}`)
            .fontSize(big ? 22 : 17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .opacity(0.92)
        }
        .width('100%')
        .height(h)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(color)
        .borderRadius({ topLeft: 14, topRight: 14 })
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Text('←')
            .fontSize(22)
            .fontColor($r('app.color.text_main'))
            .onClick(() => {
              router.back()
            })
          Blank()
          Text($r('app.string.title_weekrank')).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Blank()
          Row().width(22)
        }
        .width('100%')
        .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

        // 我的周减排 · 渐变 Hero 卡
        Row() {
          Column() {
            Text('近 7 天 · 我的减排量')
              .fontSize(12)
              .fontColor('#BFE3EC')
            Row() {
              Text(this.myWeek.toFixed(2))
                .fontSize(32)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
              Text(' kg CO₂e')
                .fontSize(12)
                .fontColor('#BFE3EC')
                .margin({ left: 6, bottom: 6 })
            }
            .alignItems(VerticalAlign.Bottom)
            .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Column() {
            Image($rawfile('icons/ic_leaf.svg'))
              .width(28).height(28).fillColor(Color.White)
          }
          .justifyContent(FlexAlign.Center)
          .width(52)
          .height(52)
          .borderRadius(16)
          .backgroundColor('#26FFFFFF')
        }
        .width('100%')
        .padding(ZeroTheme.padL)
        .linearGradient({ angle: 135, colors: [[$r('app.color.brand_deep'), 0], [$r('app.color.primary'), 1]] })
        .borderRadius(ZeroTheme.radiusL)
        .margin({ top: 12 })

        // 领奖台(前三名)
        Column() {
          Row() {
            Text('本周领奖台')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_main'))
            Blank()
            Text('按近 7 天减排量')
              .fontSize(10)
              .fontColor($r('app.color.text_sub'))
          }
          .width('100%')

          if (this.rows.length >= 3) {
            Row({ space: 10 }) {
              this.podiumCol(1, 2, $r('app.color.podium_silver'), 74, false)
              this.podiumCol(0, 1, $r('app.color.gold_deep'), 110, true)
              this.podiumCol(2, 3, $r('app.color.podium_bronze'), 56, false)
            }
            .alignItems(VerticalAlign.Bottom)
            .width('100%')
            .margin({ top: 16 })
          }
        }
        .width('100%')
        .padding(ZeroTheme.padL)
        .backgroundColor($r('app.color.card'))
        .borderRadius(ZeroTheme.radiusL)
        .shadow({ radius: 14, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 5 })
        .margin({ top: 12 })

        // 空状态引导(无舍友数据时)
        if (!this.hasMates) {
          Column({ space: 8 }) {
            Text('榜单空空的,还没有舍友数据')
              .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
            Text('把你的周数据包发给舍友,TA 导入后再把数据包发回来,即可生成宿舍榜;也可以先放几位演示对手看看效果')
              .fontSize(11)
              .fontColor($r('app.color.text_sub'))
              .lineHeight(17)
              .textAlign(TextAlign.Center)
            Button('生成演示对手(路演用)')
              .fontSize(12)
              .height(34)
              .backgroundColor($r('app.color.sand'))
              .fontColor($r('app.color.text_main'))
              .onClick(() => {
                this.addDemoMates()
              })
          }
          .alignItems(HorizontalAlign.Center)
          .width('100%')
          .padding(ZeroTheme.padL)
          .backgroundColor($r('app.color.card'))
          .borderRadius(ZeroTheme.radiusL)
          .margin({ top: 12 })
        }

        // 第四名起
        ForEach(this.rows, (r: RankRow, i: number) => {
          if (i >= 3) {
            Row() {
              Text(`${i + 1}`)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_sub'))
                .width(26)
                .height(26)
                .textAlign(TextAlign.Center)
                .backgroundColor($r('app.color.chip_bg'))
                .borderRadius(13)
              Text(r.name)
                .fontSize(14)
                .fontWeight(r.me ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(r.me ? $r('app.color.primary') : $r('app.color.text_main'))
                .margin({ left: 10 })
              if (r.me) {
                Text('我')
                  .fontSize(9)
                  .fontColor(Color.White)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor($r('app.color.primary'))
                  .borderRadius(8)
                  .margin({ left: 6 })
              }
              Blank()
              Text(`${r.co2.toFixed(2)} kg`)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(r.me ? $r('app.color.primary') : $r('app.color.text_main'))
            }
            .width('100%')
            .padding(ZeroTheme.padM)
            .backgroundColor(r.me ? $r('app.color.primary_light') : $r('app.color.card'))
            .borderRadius(ZeroTheme.radiusM)
            .margin({ top: 8 })
          }
        }, (r: RankRow) => r.name + r.co2.toFixed(2))

        Row({ space: 10 }) {
          Button('导出我的数据包')
            .fontSize(12)
            .layoutWeight(1)
            .height(38)
            .backgroundColor($r('app.color.primary'))
            .onClick(() => {
              this.exportPack()
            })
          Button('导入舍友数据包')
            .fontSize(12)
            .layoutWeight(1)
            .height(38)
            .backgroundColor($r('app.color.sand'))
            .fontColor($r('app.color.text_main'))
            .onClick(() => {
              this.importPack()
            })
        }
        .width('100%')
        .margin({ top: 14 })

        Column() {
          Text('说明:数据包为本地 JSON 文件,通过系统文件选择器导出/导入,全程不经云端;导入按舍友昵称去重合并。')
            .fontSize(10).fontColor($r('app.color.text_sub')).lineHeight(16)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(ZeroTheme.padM)
        .backgroundColor($r('app.color.card'))
        .borderRadius(ZeroTheme.radiusM)
        .shadow({ radius: 12, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 4 })
        .margin({ top: 12, bottom: 24 })
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
    .backgroundColor($r('app.color.bg'))
    .align(Alignment.Top)
  }

  pageTransition() {
    PageTransitionEnter({ duration: ZeroMotion.pageDurIn, curve: Curve.Friction })
      .opacity(0)
      .translate({ y: 16 })
    PageTransitionExit({ duration: ZeroMotion.pageDurOut, curve: Curve.Friction })
      .opacity(0)
  }
}
