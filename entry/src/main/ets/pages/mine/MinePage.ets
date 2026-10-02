import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { ZeroMotion } from '../../common/Motion'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { Database, Summary } from '../../data/Database'
import { ISLAND_STAGES } from '../../model/Models'
import { DemoData } from '../../service/DemoData'

interface MineMenu {
  icon: string
  tint: string
  title: string
  desc: string
  url: string
}

/** 我的页面(从首页头像进入) */
@Entry
@Component
struct MinePage {
  @State ecoValue: number = 0
  @State stageName: string = '灰屿'
  private menus: MineMenu[] = [
    { icon: 'ic_search', tint: '#0E7C86', title: '记录明细', desc: '逐条碳账本 · 按时段/分类查询与删除', url: 'pages/records/RecordListPage' },
    { icon: 'ic_bill', tint: '#D97706', title: '年度碳账单', desc: '你的年度低碳报告长图', url: 'pages/poster/PosterPage' },
    { icon: 'ic_tree', tint: '#2E7D5B', title: '我的植树证书', desc: '认植真树的电子凭证,支持分享', url: 'pages/certificate/CertificatePage' },
    { icon: 'ic_rank', tint: '#D97706', title: '我的徽章', desc: '低碳行动攒下的徽章墙', url: 'pages/badge/BadgePage' },
    { icon: 'ic_book', tint: '#059669', title: '岛屿图鉴', desc: '里程碑解锁的物种收集', url: 'pages/dex/DexPage' },
    { icon: 'ic_rank', tint: '#4E8FB8', title: '宿舍碳排周榜', desc: '导入舍友数据包,生成宿舍榜单', url: 'pages/rank/WeekRankPage' },
    { icon: 'ic_backup', tint: '#0E5E6F', title: '备份与导出', desc: 'JSON 全量备份 · CSV 报表导出', url: 'pages/mine/BackupPage' },
    { icon: 'ic_bank', tint: '#C583D6', title: '碳普惠平台', desc: '模拟城市碳普惠接口,积分互通兑换', url: 'pages/carbon/CarbonPlusPage' },
    { icon: 'ic_gear', tint: '#64748B', title: '设置', desc: '每日提醒 · 关于零屿', url: 'pages/mine/SettingsPage' }
  ]

  /** 数据变更回调(保存引用,退订时只移除本页订阅) */
  private readonly onDataChanged: () => void = () => {
    this.loadStats()
  }

  aboutToAppear(): void {
    emitter.on({ eventId: EVT_DATA_CHANGED }, this.onDataChanged)
    this.loadStats()
  }

  aboutToDisappear(): void {
    emitter.off(EVT_DATA_CHANGED, this.onDataChanged)
  }

  private async loadStats(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const s: Summary = await Database.summary(ctx)
    this.ecoValue = s.totalCo2
    let idx: number = 0
    for (let i = 0; i < ISLAND_STAGES.length; i++) {
      if (this.ecoValue >= ISLAND_STAGES[i].thresholdKg) {
        idx = i
      }
    }
    this.stageName = ISLAND_STAGES[idx].name
  }

  private showAbout(): void {
    AlertDialog.show({
      title: '零屿 Zero Isle',
      message: 'v1.0 · 每一次低碳选择,都在给你的岛种下一片绿 · 全部数据仅存储在本机,离线可用',
      autoCancel: true
    })
  }

  private genDemo(): void {
    AlertDialog.show({
      title: '生成演示数据?',
      message: '将先清空现有全部记录,再生成约 3 周的演示数据。此操作不可恢复。',
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '生成',
        fontColor: $r('app.color.primary'),
        action: () => {
          const ctx = getContext(this) as common.UIAbilityContext
          DemoData.generate(ctx).then((n: number) => {
            emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
            toast(`已生成 ${n} 条演示记录,岛屿正在生长`)
          })
        }
      }
    })
  }

  private clearAll(): void {
    AlertDialog.show({
      title: '确认清空?',
      message: '将删除全部行为记录、任务与兑换进度、证书与平台账务;保留外观、昵称、LLM Key 与收藏等设置。此操作不可恢复。',
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确认清空',
        fontColor: '#D96C5F',
        action: () => {
          const ctx = getContext(this) as common.UIAbilityContext
          Database.clearAll(ctx).then(() => {
            emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
            toast('已清空全部记录')
          })
        }
      }
    })
  }

  build() {
    Column() {
      // 顶部
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor($r('app.color.text_main'))
          .onClick(() => {
            router.back()
          })
        Blank()
        Text($r('app.string.title_mine')).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Row().width(22)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      // 用户卡
      Row() {
        Column().width(52).height(52).borderRadius(999).backgroundColor($r('app.color.primary_light'))
          .hitTestBehavior(HitTestMode.None)
        Column() {
          Text('岛主').fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text(`生态值 ${this.ecoValue.toFixed(1)} kg · ${this.stageName}阶段`).fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })

        Image($rawfile('icons/ic_leaf.svg'))
          .width(30).height(30).fillColor($r('app.color.life'))
      }
      .width('100%')
      .padding(ZeroTheme.padL)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(ZeroTheme.radiusL)
      .shadow({ radius: 14, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 5 })
      .margin({ top: 12 })

      // 演示工具(路演/自检用)
      Row({ space: 10 }) {
        Button('生成演示数据')
          .fontSize(13)
          .layoutWeight(1)
          .backgroundColor($r('app.color.primary'))
          .onClick(() => {
            this.genDemo()
          })
        Button('清空数据')
          .fontSize(13)
          .layoutWeight(1)
          .backgroundColor($r('app.color.clear_btn'))
          .onClick(() => {
            this.clearAll()
          })
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
      .margin({ top: 10 })

      // 菜单
      List({ space: 8 }) {
        ForEach(this.menus, (m: MineMenu) => {
          ListItem() {
            Row() {
              Column() {
                Image($rawfile(`icons/${m.icon}.svg`))
                  .width(20).height(20).fillColor($r('app.color.text_light'))
              }
              .justifyContent(FlexAlign.Center)
              .width(38).height(38)
              .borderRadius(12)
              .backgroundColor(m.tint)
              Column() {
                Text(m.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                Text(m.desc).fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 12 })

              Text('›').fontSize(18).fontColor($r('app.color.text_sub'))
            }
            .width('100%')
            .padding(ZeroTheme.padM)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(ZeroTheme.radiusM)
            .shadow({ radius: 10, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 3 })
            .clickEffect({ level: ClickEffectLevel.LIGHT })
            .onClick(() => {
              router.pushUrl({ url: m.url })
            })
          }
        }, (m: MineMenu) => m.title)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 14, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: 720 })
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
