import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { componentSnapshot } from '@kit.ArkUI'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { Database, Summary } from '../../data/Database'
import { ISLAND_STAGES } from '../../model/Models'

/** 年度碳账单海报:componentSnapshot 截图保存(本机) */
@Entry
@Component
struct PosterPage {
  @State totalCo2: number = 0
  @State points: number = 0
  @State streakDays: number = 0
  @State saving: boolean = false
  private posterId: string = 'zeroisle_poster'

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    const p1: Promise<Summary> = Database.summary(ctx)
    const p2: Promise<number> = Database.streak(ctx)
    Promise.all([p1, p2]).then((values) => {
      this.totalCo2 = values[0].totalCo2
      this.points = values[0].totalPoints
      this.streakDays = values[1]
    })
  }

  private stageName(): string {
    let name: string = ISLAND_STAGES[0].name
    for (const s of ISLAND_STAGES) {
      if (this.totalCo2 >= s.thresholdKg) {
        name = s.name
      }
    }
    return name
  }

  private savePoster(): void {
    if (this.saving) {
      return
    }
    this.saving = true
    componentSnapshot.get(this.posterId).then((pm: image.PixelMap) => {
      const packer = image.createImagePacker()
      const packOpts: image.PackingOption = { format: 'image/png', quality: 95 }
      const ctx = getContext(this) as common.UIAbilityContext
      const path: string = `${ctx.filesDir}/zeroisle-poster-${Date.now()}.png`
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      packer.packToFile(pm, file.fd, packOpts).then(() => {
        fs.closeSync(file)
        this.saving = false
        toast('海报已保存到应用目录,可在文件管理查看')
      }).catch(() => {
        fs.closeSync(file)
        this.saving = false
        toast('海报编码失败,请重试')
      })
    }).catch(() => {
      this.saving = false
      toast('海报生成失败,请重试')
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
        Text('我的碳账单').fontSize(18).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
        Blank()
        Row().width(22)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      Scroll() {
        Column() {
          // ===== 海报主体(可截图) =====
          Column() {
            Text('零屿 · 我的低碳账单')
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#EAD9B0')
              .letterSpacing(2)

            Text(`${this.totalCo2.toFixed(1)}`)
              .fontSize(72).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              .margin({ top: 18 })
            Text('kg 累计碳减排')
              .fontSize(13).fontColor('rgba(255,255,255,0.75)').margin({ top: 2 })

            Row({ space: 22 }) {
              Column() {
                Text('🚗').fontSize(22)
                Text(`${(this.totalCo2 / 0.2).toFixed(0)}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                Text('公里少开车').fontSize(9).fontColor('rgba(255,255,255,0.7)')
              }
              Column() {
                Text('🌳').fontSize(22)
                Text(`${(this.totalCo2 / 10).toFixed(1)}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                Text('棵树当量').fontSize(9).fontColor('rgba(255,255,255,0.7)')
              }
              Column() {
                Text('🔥').fontSize(22)
                Text(`${this.streakDays}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                Text('天连续打卡').fontSize(9).fontColor('rgba(255,255,255,0.7)')
              }
              Column() {
                Text('🪙').fontSize(22)
                Text(`${this.points}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                Text('累计岛币').fontSize(9).fontColor('rgba(255,255,255,0.7)')
              }
            }
            .margin({ top: 22 })

            Divider().color('rgba(234,217,176,0.4)').margin({ top: 20 })

            Text(`岛屿阶段:${this.stageName()}`)
              .fontSize(12).fontColor('#EAD9B0').margin({ top: 14 })
            Text('每一次低碳选择,都在给你的岛种下一片绿')
              .fontSize(11).fontColor('rgba(255,255,255,0.85)').margin({ top: 6 })
            Text(new Date().getFullYear().toString())
              .fontSize(10).fontColor('rgba(255,255,255,0.5)').margin({ top: 8 })
          }
          .width('100%')
          .padding({ top: 30, bottom: 26, left: 20, right: 20 })
          .backgroundImage($rawfile('poster_bg.jpg'), ImageRepeat.NoRepeat)
          .backgroundImageSize(ImageSize.Cover)
          .borderRadius(ZeroTheme.radiusL)
          .alignItems(HorizontalAlign.Center)
          .id(this.posterId)

          Button(this.saving ? '生成中…' : '保存海报到本机')
            .fontSize(14)
            .width('100%')
            .height(44)
            .backgroundColor(ZeroTheme.primary)
            .margin({ top: 16, bottom: 20 })
            .onClick(() => {
              this.savePoster()
            })
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
