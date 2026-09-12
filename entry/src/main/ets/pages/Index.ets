import { ZeroTheme, ZeroIcon } from '../common/Theme'
import { IslandPage } from './island/IslandPage'
import { RecordPage } from './record/RecordPage'
import { StatsPage } from './stats/StatsPage'
import { TaskPage } from './task/TaskPage'
import { LabPage } from './lab/LabPage'

/** 零屿主入口:五页 Tab(屿/记/析/营/验),矢量图标 TabBar */
@Entry
@Component
struct Index {
  @State currentIndex: number = 0
  private tabsController: TabsController = new TabsController()

  @Builder
  tabBarBuilder(title: string, index: number) {
    Column() {
      Image($rawfile(`tab/${ZeroIcon.tabFiles[index]}.png`))
        .width(24)
        .height(24)
        .fillColor(this.currentIndex === index ? ZeroTheme.primary : ZeroTheme.textSub)
        .margin({ bottom: 3 })
        .scale({ x: this.currentIndex === index ? 1.12 : 1, y: this.currentIndex === index ? 1.12 : 1 })
      Text(title)
        .fontSize(10)
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentIndex === index ? ZeroTheme.primary : ZeroTheme.textSub)
    }
    .justifyContent(FlexAlign.Center)
    .height('100%')
    .animation({ duration: ZeroTheme.durMicro, curve: Curve.EaseOut })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
      TabContent() {
        IslandPage()
      }.tabBar(this.tabBarBuilder('屿', 0))

      TabContent() {
        RecordPage()
      }.tabBar(this.tabBarBuilder('记', 1))

      TabContent() {
        StatsPage()
      }.tabBar(this.tabBarBuilder('析', 2))

      TabContent() {
        TaskPage()
      }.tabBar(this.tabBarBuilder('营', 3))

      TabContent() {
        LabPage()
      }.tabBar(this.tabBarBuilder('验', 4))
    }
    .scrollable(false)
    .barHeight(52)
    .backgroundColor(ZeroTheme.bg)
    .onChange((index: number) => {
      this.currentIndex = index
    })
  }
}
