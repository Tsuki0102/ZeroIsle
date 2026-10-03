import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { fileIo as fs, picker, fileUri } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { componentSnapshot } from '@kit.ArkUI'
import { systemShare } from '@kit.ShareKit'
import { ZeroTheme } from '../../common/Theme'
import { ZeroMotion } from '../../common/Motion'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { Database, Summary } from '../../data/Database'
import { ISLAND_STAGES, STAGE_THEMES, IslandStage } from '../../model/Models'

/** 年度碳账单海报:componentSnapshot 截图保存(本机) */
@Entry
@Component
struct PosterPage {
  @State totalCo2: number = 0
  @State points: number = 0
  @State streakDays: number = 0
  @State recordCount: number = 0
  @State saving: boolean = false
  private posterId: string = 'zeroisle_poster'

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    const p1: Promise<Summary> = Database.summary(ctx)
    const p2: Promise<number> = Database.streak(ctx)
    Promise.all([p1, p2]).then((values) => {
      this.totalCo2 = values[0].totalCo2
      this.points = values[0].totalPoints
      this.recordCount = values[0].count
      this.streakDays = values[1]
    })
  }

  private stageIdx(): number {
    let idx: number = 0
    for (let i = 0; i < ISLAND_STAGES.length; i++) {
      if (this.totalCo2 >= ISLAND_STAGES[i].thresholdKg) {
        idx = i
      }
    }
    return idx
  }

  private stageName(): string {
    return ISLAND_STAGES[this.stageIdx()].name
  }

  /** 当前阶段内的成长进度(0~1),用于海报进度条 */
  private stageProgress(): number {
    const idx: number = this.stageIdx()
    if (idx >= ISLAND_STAGES.length - 1) {
      return 1
    }
    const cur: number = ISLAND_STAGES[idx].thresholdKg
    const next: number = ISLAND_STAGES[idx + 1].thresholdKg
    return Math.min(1, Math.max(0.02, (this.totalCo2 - cur) / (next - cur)))
  }

  private savePoster(): void {
    if (this.saving) {
      return
    }
    this.saving = true
    componentSnapshot.get(this.posterId).then((pm: image.PixelMap) => {
      // 系统文件选择器:保存到用户可见位置(下载/文件管理等),而非应用沙箱
      const opt: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
      opt.newFileNames = [`zeroisle-poster-${Database.today()}.png`]
      new picker.DocumentViewPicker().save(opt).then((uris: Array<string>) => {
        if (uris.length === 0) {
          this.saving = false
          toast('已取消保存')
          return
        }
        const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
        const packer = image.createImagePacker()
        const packOpts: image.PackingOption = { format: 'image/png', quality: 95 }
        packer.packToFile(pm, file.fd, packOpts).then(() => {
          fs.closeSync(file)
          this.saving = false
          toast('海报已保存,可在文件管理/相册查看')
        }).catch(() => {
          fs.closeSync(file)
          this.saving = false
          toast('海报编码失败,请重试')
        })
      }).catch(() => {
        this.saving = false
        toast('已取消保存')
      })
    }).catch(() => {
      this.saving = false
      toast('海报生成失败,请重试')
    })
  }

  /** 分享海报:截图编码到缓存 → systemShare 系统分享面板(社交分享) */
  private sharePoster(): void {
    if (this.saving) {
      return
    }
    this.saving = true
    componentSnapshot.get(this.posterId).then((pm: image.PixelMap) => {
      const packer = image.createImagePacker()
      const packOpts: image.PackingOption = { format: 'image/png', quality: 95 }
      const ctx = getContext(this) as common.UIAbilityContext
      const path: string = `${ctx.cacheDir}/zeroisle-share-${Date.now()}.png`
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      packer.packToFile(pm, file.fd, packOpts).then(() => {
        fs.closeSync(file)
        this.saving = false
        const record: systemShare.SharedRecord = {
          utd: 'general.image',
          uri: fileUri.getUriFromPath(path),
          title: '零屿 · 我的年度低碳账单',
          description: `累计碳减排 ${this.totalCo2.toFixed(1)} kg,每一次低碳选择都在给岛种下一片绿`
        }
        const data: systemShare.SharedData = new systemShare.SharedData(record)
        const controller: systemShare.ShareController = new systemShare.ShareController(data)
        controller.show(ctx, { previewMode: systemShare.SharePreviewMode.DETAIL }).catch(() => {
          toast('分享面板调起失败,可先保存海报')
        })
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
          .fontSize(22).fontColor($r('app.color.text_main'))
          .onClick(() => {
            router.back()
          })
        Blank()
        Text($r('app.string.title_poster')).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Row().width(22)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      Scroll() {
        Column() {
          // ===== 海报主体(可截图) =====
          Stack({ alignContent: Alignment.TopStart }) {
            // 装饰层:植物剪影 + 金色圆环(绝对定位,不占布局)
            Image($rawfile('icons/ic_tree.svg'))
              .width(190).height(190)
              .fillColor('#FFFFFF').opacity(0.055)
              .position({ x: '72%', y: -36 })
              .rotate({ angle: 12 })
            Image($rawfile('icons/ic_leaf.svg'))
              .width(150).height(150)
              .fillColor('#EAD9B0').opacity(0.07)
              .position({ x: -38, y: '66%' })
              .rotate({ angle: -14 })
            Column()
              .width(250).height(250)
              .border({ width: 1, color: 'rgba(234,217,176,0.14)' })
              .borderRadius(999)
              .position({ x: -80, y: -80 })
            Column()
              .width(120).height(120)
              .border({ width: 1, color: 'rgba(255,255,255,0.09)' })
              .borderRadius(999)
              .position({ x: '70%', y: '72%' })

            // 内容层
            Column() {
              // 品牌行
              Row() {
                Image($rawfile('icons/ic_leaf.svg'))
                  .width(15).height(15).fillColor('#EAD9B0')
                Text(' 零屿 Zero Isle')
                  .fontSize(13).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                  .fontFamily(ZeroTheme.fontNum)
                Blank()
                Text('2026 年度账单')
                  .fontSize(10).fontWeight(FontWeight.Medium).fontColor('#EAD9B0')
                  .padding({ left: 9, right: 9, top: 3, bottom: 3 })
                  .border({ width: 1, color: 'rgba(234,217,176,0.55)' })
                  .borderRadius(999)
                  .backgroundColor('rgba(234,217,176,0.10)')
              }
              .width('100%')

              // 主数字
              Column() {
                Text('累 计 碳 减 排')
                  .fontSize(12).fontColor('rgba(255,255,255,0.72)')
                  .letterSpacing(6)
                  .margin({ top: 22 })
                Row() {
                  Text(this.totalCo2.toFixed(1))
                    .fontSize(74).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                    .fontFamily(ZeroTheme.fontNumBlack)
                  Text(' kg CO₂e')
                    .fontSize(14).fontColor('rgba(255,255,255,0.78)')
                    .margin({ left: 8, bottom: 14 })
                }
                .alignItems(VerticalAlign.Bottom)
                .margin({ top: 2 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)

              // 等价物换算 2×2(内联写法:@Builder 按值传参不随 @State 刷新,历史坑)
              Column({ space: 9 }) {
                Row({ space: 9 }) {
                  Column({ space: 4 }) {
                    Image($rawfile('icons/ic_bike.svg')).width(19).height(19).fillColor('#EAD9B0')
                    Text(`${(this.totalCo2 / 0.2).toFixed(0)}`)
                      .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                      .fontFamily(ZeroTheme.fontNum)
                    Text('公里 · 少开车').fontSize(9.5).fontColor('rgba(255,255,255,0.66)')
                  }
                  .layoutWeight(1).width('100%')
                  .padding({ top: 11, bottom: 11 })
                  .backgroundColor('rgba(255,255,255,0.09)')
                  .borderRadius(13)
                  .border({ width: 1, color: 'rgba(255,255,255,0.13)' })

                  Column({ space: 4 }) {
                    Image($rawfile('icons/ic_tree.svg')).width(19).height(19).fillColor('#EAD9B0')
                    Text(`${(this.totalCo2 / 10).toFixed(1)}`)
                      .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                      .fontFamily(ZeroTheme.fontNum)
                    Text('棵 · 树木固碳').fontSize(9.5).fontColor('rgba(255,255,255,0.66)')
                  }
                  .layoutWeight(1).width('100%')
                  .padding({ top: 11, bottom: 11 })
                  .backgroundColor('rgba(255,255,255,0.09)')
                  .borderRadius(13)
                  .border({ width: 1, color: 'rgba(255,255,255,0.13)' })
                }
                .width('100%')

                Row({ space: 9 }) {
                  Column({ space: 4 }) {
                    Image($rawfile('icons/ic_fire.svg')).width(19).height(19).fillColor('#EAD9B0')
                    Text(`${this.streakDays}`)
                      .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                      .fontFamily(ZeroTheme.fontNum)
                    Text('天 · 连续打卡').fontSize(9.5).fontColor('rgba(255,255,255,0.66)')
                  }
                  .layoutWeight(1).width('100%')
                  .padding({ top: 11, bottom: 11 })
                  .backgroundColor('rgba(255,255,255,0.09)')
                  .borderRadius(13)
                  .border({ width: 1, color: 'rgba(255,255,255,0.13)' })

                  Column({ space: 4 }) {
                    Image($rawfile('icons/ic_coin.svg')).width(19).height(19).fillColor('#EAD9B0')
                    Text(`${this.points}`)
                      .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                      .fontFamily(ZeroTheme.fontNum)
                    Text('枚 · 累计岛币').fontSize(9.5).fontColor('rgba(255,255,255,0.66)')
                  }
                  .layoutWeight(1).width('100%')
                  .padding({ top: 11, bottom: 11 })
                  .backgroundColor('rgba(255,255,255,0.09)')
                  .borderRadius(13)
                  .border({ width: 1, color: 'rgba(255,255,255,0.13)' })
                }
                .width('100%')
              }
              .width('100%')
              .margin({ top: 20 })

              // 岛屿成长进度
              Column({ space: 8 }) {
                Row() {
                  Text('岛屿成长')
                    .fontSize(10).fontColor('rgba(255,255,255,0.62)')
                    .letterSpacing(2)
                  Blank()
                  Text(`${this.stageName()} · ${STAGE_THEMES[this.stageIdx()].tag}`)
                    .fontSize(11).fontWeight(FontWeight.Medium).fontColor('#EAD9B0')
                }
                .width('100%')

                Stack({ alignContent: Alignment.Start }) {
                  Row()
                    .width('100%').height(7)
                    .backgroundColor('rgba(255,255,255,0.16)')
                    .borderRadius(999)
                  Row()
                    .width(`${Math.round(this.stageProgress() * 100)}%`).height(7)
                    .linearGradient({ angle: 90, colors: [['#EAD9B0', 0], ['#D4AF37', 1]] })
                    .borderRadius(999)
                }
                .width('100%')

                Row() {
                  ForEach(ISLAND_STAGES, (s: IslandStage, i: number) => {
                    Text(s.name)
                      .fontSize(8.5)
                      .fontColor(i === this.stageIdx() ? '#EAD9B0' : 'rgba(255,255,255,0.45)')
                      .fontWeight(i === this.stageIdx() ? FontWeight.Bold : FontWeight.Normal)
                      .layoutWeight(1)
                      .textAlign(i === 0 ? TextAlign.Start : (i === ISLAND_STAGES.length - 1 ? TextAlign.End : TextAlign.Center))
                  }, (s: IslandStage) => s.name)
                }
                .width('100%')
              }
              .width('100%')
              .margin({ top: 20 })

              // 金色装饰分隔
              Row({ space: 10 }) {
                Column().layoutWeight(1).height(1).backgroundColor('rgba(234,217,176,0.35)')
                Text('🌿').fontSize(11)
                Column().layoutWeight(1).height(1).backgroundColor('rgba(234,217,176,0.35)')
              }
              .width('100%')
              .margin({ top: 20 })

              // 落款
              Text('每一次低碳选择,都在给你的岛种下一片绿')
                .fontSize(11.5).fontColor('rgba(255,255,255,0.85)')
                .margin({ top: 14 })
              Text(`本年度记录 ${this.recordCount} 笔低碳行为 · 零屿 Zero Isle 出品`)
                .fontSize(9).fontColor('rgba(255,255,255,0.5)')
                .margin({ top: 7 })
            }
            .width('100%')
            .padding({ top: 20, bottom: 22, left: 18, right: 18 })
          }
          .width('100%')
          .linearGradient({
            angle: 158,
            colors: [['#175244', 0], ['#0E3B31', 0.55], ['#082B24', 1]]
          })
          .borderRadius(ZeroTheme.radiusL)
          .clip(true)
          .shadow({ radius: 24, color: 'rgba(10,45,38,0.35)', offsetX: 0, offsetY: 10 })
          .id(this.posterId)

          Text('保存为 PNG 后可直接分享到朋友圈 / 群聊')
            .fontSize(10.5).fontColor($r('app.color.text_sub'))
            .margin({ top: 12 })

          Row({ space: 10 }) {
            Button(this.saving ? '生成中…' : '保存海报到本机')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
              .height(ZeroTheme.btnHeight)
              .backgroundColor($r('app.color.primary'))
              .borderRadius(ZeroTheme.radiusPill)
              .clickEffect({ level: ClickEffectLevel.LIGHT })
              .onClick(() => {
                this.savePoster()
              })
            Button('分享海报')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
              .height(ZeroTheme.btnHeight)
              .backgroundColor($r('app.color.sand'))
              .fontColor($r('app.color.text_main'))
              .borderRadius(ZeroTheme.radiusPill)
              .clickEffect({ level: ClickEffectLevel.LIGHT })
              .onClick(() => {
                this.sharePoster()
              })
          }
          .width('100%')
          .margin({ top: 14, bottom: 20 })
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
