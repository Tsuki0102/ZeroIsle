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

/** 一条行为记录(Step 3 入库) */
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
  source: '手动' | '语义' | '拍照' | '抄表'
  createdAt: number
}

/** 每日任务/校园挑战 */
export interface CampusTask {
  id: string
  name: string
  desc: string
  rewardPoints: number
  icon: string
}

/** 科普文章(碳知实验室) */
export interface LabArticle {
  id: string
  title: string
  category: string
  minutes: number
  hasCalculator: boolean
  summary: string
}

/** 积分规则:1 kgCO2e = 10 岛币 */
export const POINTS_PER_KG: number = 10

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
