/**
 * 零屿 Theme v2 ——「仿生有机 · 呼吸的岛」设计 Token
 * 依据:ui-ux-pro-max 检索结论(Biomimetic/Organic 2.0)+ 零屿品牌海青
 * 命名策略:保留 v1 既有 Token 名(全部页面零改动继承新值),新增 v2 扩展 Token
 * 深色模式:M6 接入(本版先定义浅色晨屿体系,结构已为双主题预留)
 */
export class ZeroTheme {
  // ===== 品牌 · 海青系(结构与导航) =====
  static readonly brandDeep: string = '#0A3F4C'
  static readonly primary: string = '#0E5E6F'
  static readonly primaryLight: string = '#DCEDEA'
  static readonly primaryMist: string = 'rgba(14,94,111,0.10)'

  // ===== 生命 · 岛绿系(成长/成功/生态)=====
  static readonly lifeDeep: string = '#15803D'
  static readonly life: string = '#059669'
  static readonly lifeSoft: string = '#6EE7B7'

  // ===== 强调 · 日光金 + 暖沙(岛币/能量/领取)=====
  static readonly gold: string = '#FBBF24'
  static readonly goldDeep: string = '#D97706'
  static readonly sand: string = '#F2A65A'
  static readonly sandSoft: string = '#FBE8D3'

  // ===== 背景/卡片(薄荷染底,更"活")=====
  static readonly bg: string = '#F0FDF4'
  static readonly bgDeep: string = '#ECFDF5'
  static readonly card: string = '#FFFFFF'
  static readonly glass: string = 'rgba(255,255,255,0.68)'

  // ===== 文字(浅色下对比度 ≥4.5:1)=====
  static readonly textMain: string = '#0F172A'
  static readonly textSub: string = '#475569'
  static readonly textLight: string = '#FFFFFF'
  static readonly textOnGlass: string = 'rgba(255,255,255,0.78)'

  // ===== 语义 =====
  static readonly danger: string = '#DC2626'
  static readonly ok: string = '#059669'

  // ===== 岛屿场景(兼容旧引用)=====
  static readonly islandGreen: string = '#059669'
  static readonly islandGreenDeep: string = '#15803D'
  static readonly seaBlue: string = '#9ED8DB'
  static readonly skyTop: string = '#DFF3F1'
  static readonly skyBottom: string = '#FDF6EC'

  // ===== v1 兼容别名(全页面既有引用,值映射到 v2 体系)=====
  static readonly primaryDeep: string = ZeroTheme.brandDeep
  static readonly accent: string = ZeroTheme.sand
  static readonly accentSoft: string = ZeroTheme.sandSoft
  static readonly cardBg: string = '#FFFFFF'

  // ===== 形状 · 有机变径圆角(仿生规格 16-28,每张卡像河滩石头)=====
  static readonly radiusScene: number = 24
  static readonly radiusL: number = 24
  static readonly radiusM: number = 16
  static readonly radiusS: number = 12
  /** 有机变径组合 A( hero/场景卡) */
  static readonly stoneA: RoundRadius = { topLeft: 28, topRight: 22, bottomLeft: 22, bottomRight: 28 }
  /** 有机变径组合 B(内容卡) */
  static readonly stoneB: RoundRadius = { topLeft: 20, topRight: 26, bottomLeft: 18, bottomRight: 24 }

  // ===== 间距(8dp 节奏)=====
  static readonly padL: number = 20
  static readonly padM: number = 14
  static readonly padS: number = 8

  // ===== 动效时长 Token =====
  static readonly durMicro: number = 120
  static readonly durStandard: number = 300
  static readonly durEmphasis: number = 500
  static readonly durBreath: number = 4000

  // ===== 字体 =====
  /** 数字/拉丁展示字体(EntryAbility 注册,rawfile 打包) */
  static readonly fontNum: string = 'NunitoDisplay'
  static readonly fontNumBlack: string = 'NunitoBlack'
  static readonly fontBase: string = 'HarmonyOS Sans'
}

interface RoundRadius {
  topLeft: number
  topRight: number
  bottomLeft: number
  bottomRight: number
}

/** 图标语义映射(TabBar/菜单矢量图标,去 emoji 化) */
export class ZeroIcon {
  static readonly tabFiles: string[] = ['tab_island', 'tab_record', 'tab_stats', 'tab_task', 'tab_lab']
}
