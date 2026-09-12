import { router } from '@kit.ArkUI'
import { ZeroTheme } from '../../common/Theme'

/** 开屏页:晨昏海平线 + 零屿标识 */
@Entry
@Component
struct SplashPage {
  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image($rawfile('splash_page.jpg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .draggable(false)

      Column() {
        Text('零屿 Zero Isle')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F3D2E')
          .shadow({ radius: 10, color: 'rgba(255,255,255,0.9)', offsetX: 0, offsetY: 0 })
        Text('每一次低碳选择,都在给你的岛种下一片绿')
          .fontSize(13)
          .fontColor('#2E5A4C')
          .margin({ top: 10 })
          .shadow({ radius: 8, color: 'rgba(255,255,255,0.85)', offsetX: 0, offsetY: 0 })
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FDF6EC')
    .onClick(() => {
      router.replaceUrl({ url: 'pages/Index' })
    })
  }

  aboutToAppear(): void {
    setTimeout(() => {
      router.replaceUrl({ url: 'pages/Index' })
    }, 1500)
  }
}
