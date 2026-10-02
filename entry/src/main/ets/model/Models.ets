/** 零屿数据模型定义 */

/** 行为大类(通知要求:出行/节水节电/光盘餐饮/旧物回收 + 绿色习惯) */
export interface BehaviorCategory {
  id: string
  name: string
  icon: string
}

/** 校园/通用场景 */
export type Scene = '通勤' | '宿舍' | '食堂' | '循环' | '通用'

/** 碳排放因子(一条低碳行为) */
export interface BehaviorFactor {
  id: string
  categoryId: string
  scene: Scene
  name: string
  unit: string
  /** 每单位行为对应的减排量 kgCO2e */
  factor: number
  tip: string
}

/** 一条行为记录 */
export interface BehaviorRecord {
  id: number
  factorId: string
  categoryId: string
  scene: string
  amount: number
  unit: string
  co2Kg: number
  points: number
  recordDate: string
  note: string
  source: '手动' | '语义' | '拍照' | '抄表' | '扫码'
  createdAt: number
}

/** 积分规则:1 kgCO2e = 10 岛币 */
export const POINTS_PER_KG: number = 10

/** 平台口径:1 kgCO2e = 1 碳积分(城市碳普惠平台上报后计入,与岛币分账) */
export const PLATFORM_POINTS_PER_KG: number = 1

/** 岛屿进化阶段 */
export interface IslandStage {
  name: string
  thresholdKg: number
  desc: string
}

export const ISLAND_STAGES: IslandStage[] = [
  { name: '灰屿', thresholdKg: 0, desc: '一切从零开始' },
  { name: '青屿', thresholdKg: 10, desc: '第一抹绿意' },
  { name: '绿屿', thresholdKg: 50, desc: '草木渐盛' },
  { name: '森屿', thresholdKg: 150, desc: '林木成荫' },
  { name: '生态屿', thresholdKg: 400, desc: '万物共生' }
]

/** 岛屿阶段主题:每个岛屿的专属配色 / 标志性图标 / 定位标签 / 一句话个性文案 */
export interface StageTheme {
  /** 主题色(徽标底色 / 状态点缀) */
  tint: string
  /** 标志性图标(rawfile/icons 下 SVG 名) */
  icon: string
  /** 定位标签(4 字,突出个性定位) */
  tag: string
  /** 一句话介绍文案 */
  intro: string
}

export const STAGE_THEMES: StageTheme[] = [
  { tint: '#6E7F8A', icon: 'ic_mountain', tag: '荒原待绿', intro: '冷雾与枯枝之间,埋着第一颗种子' },
  { tint: '#D9825B', icon: 'ic_leaf', tag: '破晓初醒', intro: '晨光落在露珠上,岛屿开始呼吸' },
  { tint: '#2E7D5B', icon: 'ic_tree', tag: '正午繁茂', intro: '帆影掠过碧海,草木正盛' },
  { tint: '#B4763A', icon: 'ic_tree', tag: '金色黄昏', intro: '风车与萤火,林木渐渐成荫' },
  { tint: '#1E8E86', icon: 'ic_leaf', tag: '万物共生', intro: '彩虹、瀑布与鲸跃的乐园' }
]
