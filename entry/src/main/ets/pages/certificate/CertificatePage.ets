import { common } from '@kit.AbilityKit'
import { router, componentSnapshot } from '@kit.ArkUI'
import { fileIo as fs, picker, fileUri } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { systemShare } from '@kit.ShareKit'
import { ZeroTheme } from '../../common/Theme'
import { ZeroMotion } from '../../common/Motion'
import { toast } from '../../common/Common'
import { CertificateService, TreeCert } from '../../service/CertificateService'
import { Medal, OrnateDivider, WaxSeal, CollectibleStyle } from '../../components/Collectibles'

/** 电子植树证书页:收藏级认植凭证(描金双层框 + 水印 + 勋章徽标 + 印章),支持署名/保存/分享 */
@Entry
@Component
struct CertificatePage {
  @State certs: TreeCert[] = []
  @State idx: number = 0
  @State holderName: string = ''
  @State saving: boolean = false
  @State loading: boolean = true
  private certId: string = 'zeroisle_tree_cert'

  aboutToAppear(): void {
    this.reload(this.readSerialParam(), false)
  }

  /** 读取路由参数中的证书编号(从商城兑换跳入时携带) */
  private readSerialParam(): string {
    try {
      const params = router.getParams() as Record<string, string>
      if (params !== undefined && params !== null && params['serial'] !== undefined) {
        return params['serial']
      }
    } catch (e) {
    }
    return ''
  }

  private reload(preferSerial: string, keepIdx: boolean): void {
    const ctx = getContext(this) as common.UIAbilityContext
    CertificateService.list(ctx).then(async (list: TreeCert[]) => {
      this.certs = list
      if (list.length === 0) {
        this.holderName = await CertificateService.profileName(ctx)
        this.loading = false
        return
      }
      let i: number = keepIdx ? Math.min(this.idx, list.length - 1) : list.length - 1
      if (!keepIdx && preferSerial !== '') {
        for (let k = 0; k < list.length; k++) {
          if (list[k].serial === preferSerial) {
            i = k
          }
        }
      }
      this.idx = i
      this.holderName = list[i].name
      this.loading = false
    })
  }

  /** 当前展示的证书(空列表时返回占位,避免越界) */
  private current(): TreeCert {
    if (this.certs.length === 0) {
      return { serial: '', name: '', co2: 0, date: '', species: '' }
    }
    return this.certs[Math.min(this.idx, this.certs.length - 1)]
  }

  private dateText(d: string): string {
    const p: string[] = d.split('-')
    if (p.length < 3) {
      return d
    }
    return `${Number(p[0])}年${Number(p[1])}月${Number(p[2])}日`
  }

  /** 更新持证人姓名:同时写入当前证书与默认署名 */
  private applyName(): void {
    const name: string = this.holderName.trim()
    if (name === '') {
      toast('请输入持证人姓名')
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    const c: TreeCert = this.current()
    if (c.serial === '') {
      CertificateService.setProfileName(ctx, name).then(() => {
        toast('署名已保存,兑换证书时会自动使用')
      })
      return
    }
    CertificateService.rename(ctx, c.serial, name).then(async () => {
      await CertificateService.setProfileName(ctx, name)
      this.reload(c.serial, true)
      toast('证书署名已更新')
    })
  }

  private saveCert(): void {
    if (this.saving) {
      return
    }
    this.saving = true
    componentSnapshot.get(this.certId).then((pm: image.PixelMap) => {
      const opt: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
      opt.newFileNames = [`zeroisle-cert-${this.current().serial}.png`]
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
          toast('证书已保存,可在文件管理/相册查看')
        }).catch(() => {
          fs.closeSync(file)
          this.saving = false
          toast('证书编码失败,请重试')
        })
      }).catch(() => {
        this.saving = false
        toast('已取消保存')
      })
    }).catch(() => {
      this.saving = false
      toast('证书生成失败,请重试')
    })
  }

  private shareCert(): void {
    if (this.saving) {
      return
    }
    this.saving = true
    componentSnapshot.get(this.certId).then((pm: image.PixelMap) => {
      const packer = image.createImagePacker()
      const packOpts: image.PackingOption = { format: 'image/png', quality: 95 }
      const ctx = getContext(this) as common.UIAbilityContext
      const path: string = `${ctx.cacheDir}/zeroisle-cert-${Date.now()}.png`
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      packer.packToFile(pm, file.fd, packOpts).then(() => {
        fs.closeSync(file)
        this.saving = false
        const c: TreeCert = this.current()
        const record: systemShare.SharedRecord = {
          utd: 'general.image',
          uri: fileUri.getUriFromPath(path),
          title: '零屿 · 我的电子植树证书',
          description: `${c.name} 累计碳减排 ${c.co2.toFixed(1)} kg,认植 ${c.species} 一株(证书编号 ${c.serial})`
        }
        const data: systemShare.SharedData = new systemShare.SharedData(record)
        const controller: systemShare.ShareController = new systemShare.ShareController(data)
        controller.show(ctx, { previewMode: systemShare.SharePreviewMode.DETAIL }).catch(() => {
          toast('分享面板调起失败,可先保存证书')
        })
      }).catch(() => {
        fs.closeSync(file)
        this.saving = false
        toast('证书编码失败,请重试')
      })
    }).catch(() => {
      this.saving = false
      toast('证书生成失败,请重试')
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
        Text('植树证书').fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Row().width(22)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      Scroll() {
        Column() {
          if (this.loading) {
            Column() {
              LoadingProgress().width(36).height(36).color($r('app.color.primary'))
            }
            .width('100%')
            .height(240)
            .justifyContent(FlexAlign.Center)
          } else if (this.certs.length === 0) {
            this.emptyView()
          } else {
            // ===== 证书主体(可截图) =====
            Column() {
              Column() {
                Stack({ alignContent: Alignment.Center }) {
                  // 水印
                  Image($rawfile('icons/ic_tree.svg'))
                    .width(210).height(210)
                    .fillColor(CollectibleStyle.goldLine)
                    .opacity(0.07)

                  Column() {
                    // 认证徽标
                    Medal({ medalIcon: 'ic_tree', unlocked: true, medalSize: 58 })
                    Text('零屿 · 低碳认证')
                      .fontSize(10).letterSpacing(4).fontColor(CollectibleStyle.goldDeep).margin({ top: 12 })
                    Row() {
                      OrnateDivider({ dividerWidth: 150 })
                    }
                    .margin({ top: 8 })

                    Text('电子植树证书')
                      .fontSize(26).fontWeight(FontWeight.Bold).fontColor(CollectibleStyle.ink).letterSpacing(6)
                      .margin({ top: 8 })
                    Text('CERTIFICATE OF TREE PLANTING')
                      .fontSize(9).letterSpacing(3).fontColor(CollectibleStyle.goldLine).margin({ top: 5 })

                    Text('兹  证  明')
                      .fontSize(12).letterSpacing(3).fontColor(CollectibleStyle.inkSoft).margin({ top: 20 })

                    Text(this.current().name)
                      .fontSize(32).fontWeight(FontWeight.Bold).fontColor(CollectibleStyle.emerald).margin({ top: 10 })

                    // 姓名下装饰纹
                    Row({ space: 6 }) {
                      Column()
                        .width(30).height(2).borderRadius(1)
                        .linearGradient({ angle: 90, colors: [['rgba(201,162,75,0)', 0], [CollectibleStyle.goldLine, 1]] })
                      Column().width(6).height(6).borderRadius(3).backgroundColor(CollectibleStyle.goldLine)
                      Column()
                        .width(30).height(2).borderRadius(1)
                        .linearGradient({ angle: 90, colors: [[CollectibleStyle.goldLine, 0], ['rgba(201,162,75,0)', 1]] })
                    }
                    .margin({ top: 10 })

                    Text('以绿色低碳的生活方式,累计减少碳排放')
                      .fontSize(12).fontColor(CollectibleStyle.inkSoft).margin({ top: 18 })

                    // 减排量高亮
                    Row() {
                      Text(`${this.current().co2.toFixed(1)} kgCO₂e`)
                        .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').fontFamily(ZeroTheme.fontNum)
                    }
                    .padding({ left: 20, right: 20, top: 7, bottom: 7 })
                    .linearGradient({ angle: 135, colors: [[CollectibleStyle.emerald, 0], [CollectibleStyle.emeraldDeep, 1]] })
                    .borderRadius(999)
                    .shadow({ radius: 8, color: 'rgba(10,60,72,0.25)', offsetY: 3 })
                    .margin({ top: 10 })

                    Text(`并于 ${this.dateText(this.current().date)} 在「零屿」以环保之名认植 ${this.current().species} 一株。`)
                      .fontSize(12).fontColor(CollectibleStyle.ink).lineHeight(20).textAlign(TextAlign.Center)
                      .margin({ top: 14 })

                    Row() {
                      OrnateDivider({ dividerWidth: 160 })
                    }
                    .margin({ top: 18 })

                    // 底部:编号信息 + 印章
                    Row() {
                      Column() {
                        Text('证书编号').fontSize(9).letterSpacing(1).fontColor(CollectibleStyle.goldDeep)
                        Text(this.current().serial)
                          .fontSize(12).fontWeight(FontWeight.Medium).fontColor(CollectibleStyle.ink)
                          .letterSpacing(1).margin({ top: 3 })
                        Text(`颁发日期 ${this.dateText(this.current().date)}`)
                          .fontSize(10).fontColor(CollectibleStyle.inkSoft).margin({ top: 8 })
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)

                      WaxSeal({ sealSize: 74, topText: '零屿', bottomText: '低碳认证' })
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                    .margin({ top: 10 })

                    Text('每一次低碳选择,都在给你的岛种下一片绿')
                      .fontSize(10).fontColor('rgba(58,46,23,0.62)').margin({ top: 16 })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Center)
                }
                .width('100%')
              }
              .width('100%')
              .padding({ top: 22, bottom: 20, left: 16, right: 16 })
              .borderRadius(18)
              .border({ width: 1, color: 'rgba(201,162,75,0.55)' })
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')
            .padding(6)
            .linearGradient({ angle: 160, colors: [[CollectibleStyle.cream, 0], [CollectibleStyle.creamDeep, 0.6], ['#EFDFBB', 1]] })
            .borderRadius(ZeroTheme.radiusL)
            .border({ width: 2.5, color: CollectibleStyle.goldLine })
            .shadow({ radius: 18, color: 'rgba(140,106,30,0.22)', offsetY: 8 })
            .id(this.certId)

            // 署名编辑
            Row({ space: 10 }) {
              TextInput({ text: this.holderName, placeholder: '输入持证人姓名' })
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .backgroundColor($r('app.color.card_bg'))
                .placeholderColor($r('app.color.text_sub'))
                .onChange((v: string) => {
                  this.holderName = v
                })
              Button('更新署名')
                .fontSize(13)
                .height(42)
                .backgroundColor($r('app.color.sand'))
                .fontColor($r('app.color.text_main'))
                .onClick(() => {
                  this.applyName()
                })
            }
            .width('100%')
            .margin({ top: 14 })

            // 我的证书切换
            if (this.certs.length > 1) {
              Scroll() {
                Row({ space: 8 }) {
                  ForEach(this.certs, (c: TreeCert, i: number) => {
                    Text(c.serial)
                      .fontSize(11)
                      .fontColor(i === this.idx ? $r('app.color.text_light') : $r('app.color.text_sub'))
                      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .backgroundColor(i === this.idx ? $r('app.color.primary') : $r('app.color.card_bg'))
                      .borderRadius(999)
                      .onClick(() => {
                        this.idx = i
                        this.holderName = c.name
                      })
                  }, (c: TreeCert, i: number) => c.serial)
                }
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
              .margin({ top: 12 })
            }

            // 操作
            Row({ space: 10 }) {
              Button(this.saving ? '生成中…' : '保存证书')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
                .height(ZeroTheme.btnHeight)
                .backgroundColor($r('app.color.primary'))
                .borderRadius(ZeroTheme.radiusPill)
                .clickEffect({ level: ClickEffectLevel.LIGHT })
                .onClick(() => {
                  this.saveCert()
                })
              Button('分享证书')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
                .height(ZeroTheme.btnHeight)
                .backgroundColor($r('app.color.sand'))
                .fontColor($r('app.color.text_main'))
                .borderRadius(ZeroTheme.radiusPill)
                .clickEffect({ level: ClickEffectLevel.LIGHT })
                .onClick(() => {
                  this.shareCert()
                })
            }
            .width('100%')
            .margin({ top: 16, bottom: 20 })
          }
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

  @Builder
  emptyView() {
    Column() {
      Medal({ medalIcon: 'ic_tree', unlocked: false, medalSize: 64 })
      Text('还没有植树证书').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main')).margin({ top: 16 })
      Text('在「低碳营地」用岛币兑换「电子植树证书」\n即可获得以你名义认植真树的电子凭证')
        .fontSize(12).fontColor($r('app.color.text_sub')).lineHeight(19).textAlign(TextAlign.Center)
        .margin({ top: 8 })
      Button('去兑换')
        .fontSize(14)
        .height(42)
        .width(160)
        .backgroundColor($r('app.color.primary'))
        .margin({ top: 18 })
        .onClick(() => {
          router.back()
        })
    }
    .width('100%')
    .padding({ top: 50, bottom: 50 })
    .alignItems(HorizontalAlign.Center)
  }
}
