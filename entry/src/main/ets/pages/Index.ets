import { ZeroTheme, ZeroIcon } from '../common/Theme'
import { ZeroMotion } from '../common/Motion'
import { window } from '@kit.ArkUI'
import { emitter } from '@kit.BasicServicesKit'
import { EVT_GO_RECORD, EVT_CARD_NAV, EVT_DATA_CHANGED, takeCardNavTarget } from '../common/Common'
import { IslandPage } from './island/IslandPage'
import { RecordPage } from './record/RecordPage'
import { StatsPage } from './stats/StatsPage'
import { TaskPage } from './task/TaskPage'
import { LabPage } from './lab/LabPage'

/** 零屿主入口:五页 Tab(屿/记/析/营/验),现代胶囊高亮 TabBar + 磨砂浮起 */
@Entry
@Component
struct Index {
  @State currentIndex: number = 0
  private tabsController: TabsController = new TabsController()
  /** 品牌进场层:首屏可见后淡出 */
  @State splashOn: boolean = true
  @State splashOpacity: number = 1
  private splashPlayed: boolean = false

  aboutToAppear(): void {
    // 冷启动:桌面卡片点击跳转目标
    if (takeCardNavTarget() === 'stats') {
      this.currentIndex = 2
    }
    // 热启动:任务「去完成」→「记」;卡片点击 →「析」
    emitter.on({ eventId: EVT_GO_RECORD }, () => {
      this.currentIndex = 1
    })
    emitter.on({ eventId: EVT_CARD_NAV }, () => {
      this.currentIndex = 2
    })
  }

  aboutToDisappear(): void {
    emitter.off(EVT_GO_RECORD)
    emitter.off(EVT_CARD_NAV)
  }

  onPageShow(): void {
    // 仅冷启动首次展示品牌进场层,回到前台不重复播放
    if (this.splashPlayed) {
      this.splashOn = false
      return
    }
    this.splashPlayed = true
    console.info('SPLASH:onPageShow')
    // 进场期间进入沉浸式全屏:消除安全区白边;且进场图顶部左暗右亮并存,
    // 任何单一状态栏文字色都必有一侧不可读,隐藏系统栏最干净。结束后恢复。
    this.setSplashStatusBar(true)
    // 停留后优雅淡出:单次 animateTo + delay(工程内已验证可靠的调度方式),
    // 勿改为嵌套 onFinish 或 setTimeout 调度 —— 实测均不触发,进场层会卡住不消失。
    this.getUIContext().animateTo({
      duration: ZeroMotion.splashOutDur,
      curve: Curve.EaseIn,
      delay: ZeroMotion.splashHold,
      onFinish: () => {
        console.info('SPLASH:fadeOut done')
        this.splashOn = false
        this.setSplashStatusBar(false)
      }
    }, () => {
      this.splashOpacity = 0
    })
  }

  /** 进场期间进入沉浸式全屏(隐藏状态栏与导航栏),内容区铺满整屏,
   *  彻底消除安全区缝隙导致的白边;结束后恢复系统栏。
   *  窗口底色同步兜底:即使系统栏切换存在一帧延迟,缝隙处显示的也是品牌色而非白。 */
  private setSplashStatusBar(hidden: boolean): void {
    const ctx = getContext(this)
    window.getLastWindow(ctx).then((w: window.Window) => {
      w.setWindowSystemBarEnable(hidden ? [] : ['status', 'navigation'])
      const dark = AppStorage.get<boolean>('darkOn') ?? false
      w.setWindowBackgroundColor(hidden ? '#0A3F4C' : (dark ? '#0C1512' : '#F4F8F6'))
      w.setWindowSystemBarProperties({
        statusBarColor: 'rgba(0,0,0,0)',
        statusBarContentColor: hidden ? '#FFFFFF' : (dark ? '#E8F1EC' : '#0F172A')
      })
    }).catch(() => {
    })
  }

  @Builder
  tabBarBuilder(title: ResourceStr, index: number) {
    Column() {
      // 图标胶囊(激活态高亮底 + 图标提亮放大)
      Column() {
        Image($rawfile(`tab/${ZeroIcon.tabFiles[index]}.svg`))
          .width(22)
          .height(22)
          .fillColor(this.currentIndex === index ? $r('app.color.primary') : $r('app.color.text_sub'))
          .scale({
            x: this.currentIndex === index ? 1.08 : 1,
            y: this.currentIndex === index ? 1.08 : 1
          })
      }
      .width(54)
      .height(30)
      .justifyContent(FlexAlign.Center)
      .borderRadius(ZeroTheme.radiusPill)
      .backgroundColor(this.currentIndex === index ? $r('app.color.primary_light') : Color.Transparent)

      Text(title)
        .fontSize(ZeroTheme.fsCaption)
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentIndex === index ? $r('app.color.primary') : $r('app.color.text_sub'))
        .margin({ top: 4 })
    }
    .justifyContent(FlexAlign.Center)
    .height('100%')
    .animation({ duration: ZeroTheme.durStandard, curve: ZeroTheme.curveStandard })
  }

  build() {
    Stack() {
      Tabs({ barPosition: BarPosition.End, index: this.currentIndex, controller: this.tabsController }) {
        TabContent() {
          IslandPage()
        }.tabBar(this.tabBarBuilder($r('app.string.tab_island'), 0))

        TabContent() {
          RecordPage()
        }.tabBar(this.tabBarBuilder($r('app.string.tab_record'), 1))

        TabContent() {
          StatsPage()
        }.tabBar(this.tabBarBuilder($r('app.string.tab_stats'), 2))

        TabContent() {
          TaskPage()
        }.tabBar(this.tabBarBuilder($r('app.string.tab_task'), 3))

        TabContent() {
          LabPage()
        }.tabBar(this.tabBarBuilder($r('app.string.tab_lab'), 4))
      }
      .scrollable(false)
      .barHeight(ZeroTheme.tabHeight)
      .barBackgroundColor($r('app.color.glass'))
      .barBackgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
      .divider({ strokeWidth: 0.5, color: $r('app.color.hairline'), startMargin: 0, endMargin: 0 })
      .barOverlap(false)
      .backgroundColor($r('app.color.bg'))
      .onChange((index: number) => {
        this.currentIndex = index
        // 切页即广播数据变更,确保各页(尤其首页「可用岛币」)与最新数据同步
        emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      })

      if (this.splashOn) {
        // 品牌进场层:整屏品牌视觉(海岛 + 日光 + 零屿字标),
        // 承接系统启动窗口后优雅淡出,揭示主界面。
        // 容器扩展至顶/底安全区并兜底品牌深青,杜绝导航栏/状态栏区域露出浅色页底。
        Stack() {
          Image($r('app.media.splash_art'))
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#0A3F4C')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .opacity(this.splashOpacity)
      }
    }
    .width('100%')
    .height('100%')
  }

  pageTransition() {
    PageTransitionEnter({ duration: ZeroMotion.pageDurIn, curve: Curve.Friction })
      .opacity(0)
      .translate({ y: 16 })
    PageTransitionExit({ duration: ZeroMotion.pageDurOut, curve: Curve.Friction })
      .opacity(0)
  }
}
