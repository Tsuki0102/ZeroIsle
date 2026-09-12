import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { Database, Summary } from '../../data/Database'
import { DemoData } from '../../service/DemoData'

interface MineMenu {
  icon: string
  title: string
  desc: string
  step: string
}

/** 我的页面(从首页头像进入) */
@Entry
@Component
struct MinePage {
  @State ecoValue: number = 0
  @State stageName: string = '灰屿'
  private menus: MineMenu[] = [
    { icon: '🧾', title: '年度碳账单', desc: '你的年度低碳报告长图', step: 'Step 10 接入' },
    { icon: '📖', title: '岛屿图鉴', desc: '里程碑解锁的物种收集', step: '' },
    { icon: '🏠', title: '宿舍碳排周榜', desc: '导入舍友数据包,生成宿舍榜单', step: '' },
    { icon: '💾', title: '备份与导出', desc: 'JSON 全量备份 · CSV 报表导出', step: '' },
    { icon: '🏦', title: '碳普惠平台', desc: '模拟城市碳普惠接口,积分互通兑换', step: '' },
    { icon: '⚙️', title: '设置', desc: '深色模式 · 提醒 · 关于', step: 'Step 11 接入' }
  ]

  aboutToAppear(): void {
    emitter.on({ eventId: EVT_DATA_CHANGED }, () => {
      this.loadStats()
    })
    this.loadStats()
  }

  private async loadStats(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext
    const s: Summary = await Database.summary(ctx)
    this.ecoValue = s.totalCo2
    const stages: number[] = [0, 10, 50, 150, 400]
    const names: string[] = ['灰屿', '青屿', '绿屿', '森屿', '生态屿']
    let idx: number = 0
    for (let i = 0; i < stages.length; i++) {
      if (this.ecoValue >= stages[i]) {
        idx = i
      }
    }
    this.stageName = names[idx]
  }

  private showAbout(): void {
    AlertDialog.show({
      title: '零屿 Zero Isle',
      message: 'v1.0 · 每一次低碳选择,都在给你的岛种下一片绿 · 全部数据仅存储在本机,离线可用',
      autoCancel: true
    })
  }

  private genDemo(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    DemoData.generate(ctx).then((n: number) => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      toast(`已生成 ${n} 条演示记录,岛屿正在生长`)
    })
  }

  private clearAll(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    Database.clearAll(ctx).then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      toast('已清空全部记录')
    })
  }

  build() {
    Column() {
      // 顶部
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor(ZeroTheme.textMain)
          .onClick(() => {
            router.back()
          })
        Blank()
        Text('我的').fontSize(18).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
        Blank()
        Row().width(22)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      // 用户卡
      Row() {
        Circle({ width: 52, height: 52 }).fill(ZeroTheme.primaryLight)
        Column() {
          Text('岛主').fontSize(17).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
          Text(`生态值 ${this.ecoValue.toFixed(1)} kg · ${this.stageName}阶段`).fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })

        Text('🌿').fontSize(30)
      }
      .width('100%')
      .padding(ZeroTheme.padL)
      .backgroundColor(ZeroTheme.cardBg)
      .borderRadius(ZeroTheme.radiusL)
      .margin({ top: 12 })

      // 演示工具(路演/自检用)
      Row({ space: 10 }) {
        Button('生成演示数据')
          .fontSize(13)
          .layoutWeight(1)
          .backgroundColor(ZeroTheme.primary)
          .onClick(() => {
            this.genDemo()
          })
        Button('清空数据')
          .fontSize(13)
          .layoutWeight(1)
          .backgroundColor('#8A5546')
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
              Text(m.icon).fontSize(22)
              Column() {
                Text(m.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(ZeroTheme.textMain)
                Text(m.desc).fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 12 })

              Text(m.step).fontSize(10).fontColor(ZeroTheme.textSub)
            }
            .width('100%')
            .padding(ZeroTheme.padM)
            .backgroundColor(ZeroTheme.cardBg)
            .borderRadius(ZeroTheme.radiusM)
            .onClick(() => {
              if (m.title === '岛屿图鉴') {
                router.pushUrl({ url: 'pages/dex/DexPage' })
              } else if (m.title === '年度碳账单') {
                router.pushUrl({ url: 'pages/poster/PosterPage' })
              } else if (m.title === '宿舍碳排周榜') {
                router.pushUrl({ url: 'pages/rank/WeekRankPage' })
              } else if (m.title === '备份与导出') {
                router.pushUrl({ url: 'pages/mine/BackupPage' })
              } else if (m.title === '碳普惠平台') {
                router.pushUrl({ url: 'pages/carbon/CarbonPlusPage' })
              } else if (m.title === '设置') {
                this.showAbout()
              } else {
                toast(`「${m.title}」${m.step}`)
              }
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
    .backgroundColor(ZeroTheme.bg)
  }
}
