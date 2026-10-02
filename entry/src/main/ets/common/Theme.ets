/**
 * 零屿 Theme v4 ——「仿生有机 · 呼吸的岛」设计体系
 * 颜色已全部资源化:浅色=resources/base/element/color.json,深色=resources/dark/element/color.json
 * 本文件沉淀非颜色 Token:圆角/间距/字号/控件尺寸/动效/按压反馈,供全站统一引用。
 * 约定:圆角走 radiusXS→radiusXL 阶梯;间距走 spaceXXS→spaceXL(4/8 节奏);字号走 fsCaption→fsDisplay。
 */
export class ZeroTheme {
  // ===== 形状 · 圆角阶梯(有机,像河滩石头)=====
  static readonly radiusXS: number = 8
  static readonly radiusS: number = 12
  static readonly radiusM: number = 16
  static readonly radiusL: number = 22
  static readonly radiusXL: number = 28
  static readonly radiusPill: number = 999
  /** 场景卡(hero)大圆角 */
  static readonly radiusScene: number = 24
  /** 有机变径组合 A( hero/场景卡) */
  static readonly stoneA: RoundRadius = { topLeft: 28, topRight: 22, bottomLeft: 22, bottomRight: 28 }
  /** 有机变径组合 B(内容卡) */
  static readonly stoneB: RoundRadius = { topLeft: 20, topRight: 26, bottomLeft: 18, bottomRight: 24 }

  // ===== 间距(4/8 节奏)=====
  static readonly spaceXXS: number = 4
  static readonly spaceXS: number = 8
  static readonly spaceS: number = 12
  static readonly spaceM: number = 16
  static readonly spaceL: number = 24
  static readonly spaceXL: number = 32
  /** 页面左右安全边距 */
  static readonly padL: number = 20
  static readonly padM: number = 14
  static readonly padS: number = 8

  // ===== 字号阶梯 =====
  static readonly fsCaption: number = 10
  static readonly fsSmall: number = 12
  static readonly fsBody: number = 14
  static readonly fsSubtitle: number = 16
  static readonly fsTitle: number = 20
  static readonly fsHeading: number = 24
  static readonly fsDisplay: number = 30
  static readonly lhTight: number = 18
  static readonly lhBody: number = 21

  // ===== 控件尺寸 =====
  static readonly btnHeight: number = 46
  static readonly btnHeightS: number = 38
  static readonly inputHeight: number = 46
  static readonly tabHeight: number = 58

  // ===== 动效时长 Token =====
  static readonly durMicro: number = 120
  static readonly durStandard: number = 240
  static readonly durEmphasis: number = 420
  static readonly durBreath: number = 4000
  /** 标准缓动曲线 */
  static readonly curveStandard: Curve = Curve.Friction
  /** 按压反馈:透明度与缩放 */
  static readonly pressOpacity: number = 0.72
  static readonly pressScale: number = 0.97

  // ===== 字体 =====
  /** 数字/拉丁展示字体(EntryAbility 注册,rawfile 打包) */
  static readonly fontNum: string = 'NunitoDisplay'
  static readonly fontNumBlack: string = 'NunitoBlack'
  static readonly fontBase: string = 'HarmonyOS Sans'

  // ===== 阴影(elevation)=====
  /** 轻浮起(信息卡) */
  static readonly shadowSoft: ShadowOptions = {
    radius: 12, color: '#12000000', offsetX: 0, offsetY: 4
  }
  /** 中浮起(强调卡/悬浮元素) */
  static readonly shadowMedium: ShadowOptions = {
    radius: 20, color: '#1F000000', offsetX: 0, offsetY: 8
  }
}

interface RoundRadius {
  topLeft: number
  topRight: number
  bottomLeft: number
  bottomRight: number
}

/** 图标语义映射(TabBar 矢量图标) */
export class ZeroIcon {
  static readonly tabFiles: string[] = ['tab_island', 'tab_record', 'tab_stats', 'tab_task', 'tab_lab']
}
