let storage = new LocalStorage()

@Entry(storage)
@Component
struct WidgetCard {
  @LocalStorageProp('today') today: string = '0.00'
  @LocalStorageProp('points') points: string = '0'
  @LocalStorageProp('streak') streak: string = '0'
  @LocalStorageProp('stage') stage: string = '灰屿'

  build() {
    Stack() {
      Image($rawfile('widget_bg.jpg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      Column() {
        Row() {
          Row() {
            Image($rawfile('icons/ic_leaf.svg'))
              .width(14)
              .height(14)
              .fillColor('#EAD9B0')
            Text('零屿')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#EAD9B0')
              .margin({ left: 3 })
          }
          Blank()
          Text(this.stage)
            .fontSize(10)
            .fontColor('rgba(234,217,176,0.9)')
            .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            .backgroundColor('rgba(255,255,255,0.15)')
            .borderRadius(8)
        }
        .width('100%')

        Row() {
          Text(this.today)
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text(' kg')
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.7)')
            .margin({ bottom: 6 })
        }
        .width('100%')
        .margin({ top: 8 })

        Text('今日碳减排')
          .fontSize(10)
          .fontColor('rgba(255,255,255,0.65)')

        Divider()
          .color('rgba(234,217,176,0.35)')
          .margin({ top: 8, bottom: 6 })

        Row() {
          Image($rawfile('icons/ic_coin.svg'))
            .width(12)
            .height(12)
            .fillColor('#FFFFFF')
          Text(`${this.points} 岛币`)
            .fontSize(11)
            .fontColor('#FFFFFF')
            .margin({ left: 3 })
          Blank()
          Image($rawfile('icons/ic_fire.svg'))
            .width(12)
            .height(12)
            .fillColor('#EAD9B0')
          Text(` ${this.streak} 天`)
            .fontSize(11)
            .fontColor('#EAD9B0')
            .margin({ left: 3 })
        }
        .width('100%')
      }
      .justifyContent(FlexAlign.Center)
      .padding(12)
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(8,34,44,0.42)')
      .onClick(() => {
        // 点击卡片跳转主应用「析」数据看板
        postCardAction(this, {
          action: 'router',
          abilityName: 'EntryAbility',
          params: { target: 'stats' }
        })
      })
    }
  }
}
