import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { picker, fileIo as fs } from '@kit.CoreFileKit'
import { ZeroTheme } from '../../common/Theme'
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
}

class PackEntry {
  name: string = ''
  co2: number = 0
}

class WeekPackData {
  type: string = 'weekpack'
  entries: PackEntry[] = []
}

const DEFAULT_MATES: MateEntry[] = [
  { name: '402-1 舍友', co2: 8.2 },
  { name: '402-3 舍友', co2: 5.5 },
  { name: '402-4 舍友', co2: 3.1 }
]

/** 宿舍碳排周榜:本机真实数据 + 舍友数据包导入合并(全程本地) */
@Entry
@Component
struct WeekRankPage {
  @State rows: RankRow[] = []
  @State myWeek: number = 0

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
    const rows: RankRow[] = []
    for (const m of mates) {
      rows.push({ name: m.name, co2: m.co2, me: false })
    }
    rows.push({ name: '我(本机)', co2: sum, me: true })
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
      // 首次无数据,用默认示例
    }
    return DEFAULT_MATES
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
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buf)
      fs.closeSync(file)
      const text: string = String.fromCharCode(...new Uint8Array(buf))
      const parsed = JSON.parse(text) as Record<string, Object>
      const entries = parsed['entries'] as Array<MateEntry>
      if (!Array.isArray(entries)) {
        toast('数据包格式不正确')
        return
      }
      this.loadMates(ctx).then(async (existing: MateEntry[]) => {
        const merged: MateEntry[] = existing.filter((m: MateEntry) => m.name !== '我(本机)')
        for (const e of entries) {
          if (e.name !== '我(本机)' && e.co2 >= 0) {
            const dup: MateEntry[] = merged.filter((m: MateEntry) => m.name === e.name)
            if (dup.length === 0) {
              merged.push({ name: e.name, co2: e.co2 })
            } else {
              dup[0].co2 = e.co2
            }
          }
        }
        await this.saveMates(ctx, merged)
        this.load()
        toast(`已合并 ${entries.length} 位舍友数据,榜单已更新`)
      })
    }).catch(() => {
      toast('已取消导入')
    })
  }

  /** 导出我的周数据包 */
  private exportPack(): void {
    const opt: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
    opt.newFileNames = [`zeroisle-week-${Date.now()}.json`]
    new picker.DocumentViewPicker().save(opt).then((uris: Array<string>) => {
      if (uris.length === 0) {
        return
      }
      const pack = new WeekPackData()
      const e = new PackEntry()
      e.name = '我(本机)'
      e.co2 = this.myWeek
      pack.entries.push(e)
      const data: string = JSON.stringify(pack)
      const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      fs.writeSync(file.fd, data)
      fs.closeSync(file)
      toast('周数据包已导出,发给舍友即可合并榜单')
    }).catch(() => {
      toast('已取消导出')
    })
  }

  private medal(i: number): string {
    if (i === 0) {
      return '🥇'
    }
    if (i === 1) {
      return '🥈'
    }
    if (i === 2) {
      return '🥉'
    }
    return `${i + 1}`
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
        Text('宿舍碳排周榜').fontSize(18).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
        Blank()
        Row().width(22)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      Column() {
        Text('近 7 天 · 我的减排量')
          .fontSize(12).fontColor(ZeroTheme.textSub)
        Text(`${this.myWeek.toFixed(2)} kg`)
          .fontSize(30).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
          .margin({ top: 6 })
      }
      .width('100%')
      .padding(ZeroTheme.padL)
      .backgroundColor(ZeroTheme.card)
      .borderRadius(ZeroTheme.radiusL)
      .margin({ top: 12 })

      Column() {
        ForEach(this.rows, (r: RankRow, i: number) => {
          Row() {
            Text(this.medal(i)).fontSize(18).width(34)
            Text(r.name)
              .fontSize(14)
              .fontWeight(r.me ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(r.me ? ZeroTheme.primary : ZeroTheme.textMain)
            Blank()
            Text(`${r.co2.toFixed(2)} kg`)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(r.me ? ZeroTheme.primary : ZeroTheme.textMain)
          }
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor(r.me ? ZeroTheme.primaryLight : ZeroTheme.card)
          .borderRadius(ZeroTheme.radiusM)
          .margin({ top: 8 })
        }, (r: RankRow) => r.name + r.co2.toFixed(2))
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
      .margin({ top: 12 })

      Row({ space: 10 }) {
        Button('导出我的数据包')
          .fontSize(12)
          .layoutWeight(1)
          .height(38)
          .backgroundColor(ZeroTheme.primary)
          .onClick(() => {
            this.exportPack()
          })
        Button('导入舍友数据包')
          .fontSize(12)
          .layoutWeight(1)
          .height(38)
          .backgroundColor(ZeroTheme.sand)
          .fontColor(ZeroTheme.textMain)
          .onClick(() => {
            this.importPack()
          })
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
      .margin({ top: 14 })

      Column() {
        Text('说明:数据包为本地 JSON 文件,通过系统文件选择器导出/导入,全程不经云端;导入按舍友昵称去重合并。')
          .fontSize(10).fontColor(ZeroTheme.textSub).lineHeight(16)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(ZeroTheme.padM)
      .backgroundColor(ZeroTheme.card)
      .borderRadius(ZeroTheme.radiusM)
      .margin({ top: 12 })

      Blank()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .height('100%')
    .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
    .backgroundColor(ZeroTheme.bg)
  }
}
