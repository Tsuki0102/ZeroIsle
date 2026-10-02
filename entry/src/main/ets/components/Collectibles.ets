/**
 * 零屿收藏品视觉组件库 v1
 * 统一「祖母绿 × 赤金」收藏级配色与质感,供徽章墙(BadgePage)与植树证书(CertificatePage)共享,
 * 使勋章的金属徽章语言与证书的描金/印章语言相互呼应,形成一致的收藏品体系。
 * 实现说明:全部使用 Column/Stack + 渐变/阴影/描边构建,规避 SDK 26 才支持的 shape.fill()/stroke()。
 * 命名说明:自定义属性避开 CustomComponent 内置属性方法名(如 size/width),故用 medalSize/sealSize。
 */

/** 收藏级配色 Token(两页共用,保证视觉一致) */
export class CollectibleStyle {
  static readonly goldSheen: string = '#FBF0CE'
  static readonly gold: string = '#D9B25C'
  static readonly goldDeep: string = '#8C6A1E'
  static readonly goldLine: string = '#C9A24B'
  static readonly goldLineSoft: string = 'rgba(201,162,75,0.45)'
  static readonly cream: string = '#FDFAF0'
  static readonly creamDeep: string = '#F1E3C2'
  static readonly emerald: string = '#12788C'
  static readonly emeraldDeep: string = '#0A3C48'
  static readonly emeraldRoyal: string = '#0E5E6F'
  static readonly ink: string = '#3A2E17'
  static readonly inkSoft: string = '#756239'
  static readonly sealRed: string = '#B23A2E'
  static readonly sealRedDeep: string = '#8A281E'
  static readonly lockHi: string = '#E9EFEC'
  static readonly lockMid: string = '#BFCAC5'
  static readonly lockDeep: string = '#93A19B'
  static readonly lockFaceHi: string = '#E3E9E6'
  static readonly lockFaceDeep: string = '#A9B6B0'
  static readonly lockIcon: string = '#6C7A74'
}

/** 勋章:金属外环 + 祖母绿穹面中心盘 + 描金图标;支持锁定态(灰调) */
@Component
export struct Medal {
  @Prop medalIcon: string = 'ic_leaf'
  @Prop unlocked: boolean = true
  @Prop medalSize: number = 64

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 金属外环(多段渐变模拟拉丝高光)
      Column()
        .width(this.medalSize)
        .height(this.medalSize)
        .borderRadius(this.medalSize / 2)
        .linearGradient({
          angle: 145,
          colors: this.unlocked
            ? [[CollectibleStyle.goldSheen, 0], [CollectibleStyle.gold, 0.4], [CollectibleStyle.goldDeep, 0.68], [CollectibleStyle.goldSheen, 1]]
            : [[CollectibleStyle.lockHi, 0], [CollectibleStyle.lockMid, 0.45], [CollectibleStyle.lockDeep, 0.72], [CollectibleStyle.lockHi, 1]]
        })
        .shadow({
          radius: this.unlocked ? Math.max(6, this.medalSize * 0.14) : 3,
          color: this.unlocked ? 'rgba(140,106,30,0.38)' : 'rgba(0,0,0,0.10)',
          offsetY: 3
        })
      // 斜向玻璃高光(金属斜面层次,取代生硬高光点)
      Column()
        .width(this.medalSize - 2)
        .height(this.medalSize - 2)
        .borderRadius((this.medalSize - 2) / 2)
        .linearGradient({
          angle: 320,
          colors: [['rgba(255,255,255,0.55)', 0], ['rgba(255,255,255,0)', 0.5], ['rgba(0,0,0,0.10)', 1]]
        })
        .hitTestBehavior(HitTestMode.None)
      // 内衬亮环(拉大环面层次)
      Column()
        .width(this.medalSize * 0.80)
        .height(this.medalSize * 0.80)
        .borderRadius(this.medalSize * 0.40)
        .border({ width: 1.5, color: this.unlocked ? 'rgba(255,255,255,0.38)' : 'rgba(255,255,255,0.45)' })
        .hitTestBehavior(HitTestMode.None)
      // 中心盘(径向渐变穹面,光心偏左上)
      Column()
        .width(this.medalSize * 0.70)
        .height(this.medalSize * 0.70)
        .borderRadius(this.medalSize * 0.35)
        .radialGradient({
          center: ['36%', '30%'],
          radius: '82%',
          colors: this.unlocked
            ? [[CollectibleStyle.emerald, 0], [CollectibleStyle.emeraldDeep, 1]]
            : [[CollectibleStyle.lockFaceHi, 0], [CollectibleStyle.lockFaceDeep, 1]]
        })
        .border({ width: 1, color: this.unlocked ? 'rgba(251,240,206,0.5)' : 'rgba(255,255,255,0.5)' })
      // 描金图标
      Image($rawfile(`icons/${this.medalIcon}.svg`))
        .width(this.medalSize * 0.34)
        .height(this.medalSize * 0.34)
        .fillColor(this.unlocked ? CollectibleStyle.goldSheen : CollectibleStyle.lockIcon)
        .opacity(this.unlocked ? 1 : 0.9)
    }
    .width(this.medalSize)
    .height(this.medalSize)
  }
}

/** 描金菱纹分隔线 */
@Component
export struct OrnateDivider {
  @Prop dividerWidth: number = 130

  build() {
    Row({ space: 8 }) {
      Column()
        .width(this.dividerWidth * 0.34)
        .height(1)
        .linearGradient({ angle: 90, colors: [['rgba(201,162,75,0)', 0], [CollectibleStyle.goldLine, 1]] })
      Column()
        .width(6)
        .height(6)
        .borderRadius(1.5)
        .backgroundColor(CollectibleStyle.goldLine)
        .rotate({ angle: 45 })
      Column()
        .width(this.dividerWidth * 0.34)
        .height(1)
        .linearGradient({ angle: 90, colors: [[CollectibleStyle.goldLine, 0], ['rgba(201,162,75,0)', 1]] })
    }
    .justifyContent(FlexAlign.Center)
    .height(10)
  }
}

/** 印章:双环红印 + 星徽,微倾(-8°),带投影 */
@Component
export struct WaxSeal {
  @Prop sealSize: number = 76
  @Prop topText: string = '零屿'
  @Prop bottomText: string = '低碳认证'

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(this.sealSize)
        .height(this.sealSize)
        .borderRadius(this.sealSize / 2)
        .linearGradient({ angle: 140, colors: [[CollectibleStyle.sealRed, 0], [CollectibleStyle.sealRedDeep, 1]] })
        .shadow({ radius: 8, color: 'rgba(138,40,30,0.35)', offsetY: 3 })
      Column()
        .width(this.sealSize - 9)
        .height(this.sealSize - 9)
        .borderRadius((this.sealSize - 9) / 2)
        .border({ width: 1.5, color: 'rgba(255,240,236,0.85)' })
        .hitTestBehavior(HitTestMode.None)
      Column()
        .width(this.sealSize - 20)
        .height(this.sealSize - 20)
        .borderRadius((this.sealSize - 20) / 2)
        .border({ width: 1, color: 'rgba(255,235,230,0.6)' })
        .hitTestBehavior(HitTestMode.None)
      Column({ space: 1 }) {
        Text(this.topText)
          .fontSize(this.sealSize * 0.19).fontWeight(FontWeight.Bold).fontColor('#FFF4F1').letterSpacing(1)
        Text('★').fontSize(this.sealSize * 0.11).fontColor('#FFE6E0')
        Text(this.bottomText)
          .fontSize(this.sealSize * 0.115).fontColor('#FFE6E0').letterSpacing(0.5)
      }
    }
    .width(this.sealSize)
    .height(this.sealSize)
    .rotate({ angle: -8 })
  }
}
