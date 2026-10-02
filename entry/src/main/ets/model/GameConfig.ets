/** 激励系统配置:任务 / 徽章 / 商城 */

export interface TaskDef {
  id: string
  name: string
  desc: string
  /** 矢量图标名(rawfile/icons/ 下,不含扩展名) */
  icon: string
  /** 图标底块色 */
  tint: string
  reward: number
  /** 判定式:类型:参数:目标  类型 ∈ today_count / today_sum / week_count / week_sum */
  check: string
  goal: number
  unit: string
}

/** 每日任务(按天领取) */
export const DAILY_TASKS: TaskDef[] = [
  { id: 'd_guangpan', name: '光盘打卡', desc: '今天在食堂至少光盘 1 餐', icon: 'ic_bowl', tint: '#D96C5F', reward: 20, check: 'today_count:F01:1', goal: 1, unit: '餐' },
  { id: 'd_tongqin', name: '绿色通勤', desc: '今天记录 1 次绿色出行(骑行/步行/公交…)', icon: 'ic_bike', tint: '#059669', reward: 15, check: 'today_count:travel:1', goal: 1, unit: '次' },
  { id: 'd_jieneng', name: '节能行动', desc: '今天记录 1 次节水节电行为', icon: 'ic_bolt', tint: '#D97706', reward: 15, check: 'today_count:E01:1', goal: 1, unit: '次' }
]

/** 本周挑战(按周领取) */
export const WEEK_TASKS: TaskDef[] = [
  { id: 'w_jiedian', name: '宿舍节电挑战', desc: '本周累计节约用电 5 度', icon: 'ic_bolt', tint: '#D97706', reward: 100, check: 'week_sum:energy:5', goal: 5, unit: '度' },
  { id: 'w_guangpan', name: '光盘周', desc: '本周光盘打卡 5 餐', icon: 'ic_bowl', tint: '#D96C5F', reward: 50, check: 'week_count:F01:5', goal: 5, unit: '餐' },
  { id: 'w_xingche', name: '绿色出行周', desc: '本周骑行 10 公里', icon: 'ic_bike', tint: '#059669', reward: 60, check: 'week_sum:T01:10', goal: 10, unit: '公里' },
  { id: 'w_xunhuan', name: '循环行动', desc: '本周回收/转卖 3 件旧物', icon: 'ic_recycle', tint: '#4E8FB8', reward: 40, check: 'week_count:recycle:3', goal: 3, unit: '件' }
]

export interface BadgeDef {
  id: string
  icon: string
  name: string
  desc: string
  /** 判定指标:co2 / streak / points / cat:travel 等 */
  metric: string
  threshold: number
}

/** 徽章墙(实时判定,铜银金按阈值递进;icon 为 rawfile/icons 下的 SVG 名) */
export const BADGES: BadgeDef[] = [
  { id: 'b_sprout', icon: 'ic_leaf', name: '初来乍到', desc: '累计减排 ≥ 1kg', metric: 'co2', threshold: 1 },
  { id: 'b_leaf', icon: 'ic_leaf', name: '绿意萌发', desc: '累计减排 ≥ 10kg', metric: 'co2', threshold: 10 },
  { id: 'b_isle', icon: 'ic_tree', name: '绿屿岛民', desc: '累计减排 ≥ 50kg', metric: 'co2', threshold: 50 },
  { id: 'b_guard', icon: 'ic_mountain', name: '森屿守护者', desc: '累计减排 ≥ 150kg', metric: 'co2', threshold: 150 },
  { id: 'b_week', icon: 'ic_fire', name: '七日之约', desc: '连续打卡 7 天', metric: 'streak', threshold: 7 },
  { id: 'b_persist', icon: 'ic_bolt', name: '坚持的力量', desc: '连续打卡 21 天', metric: 'streak', threshold: 21 },
  { id: 'b_commute', icon: 'ic_bus', name: '通勤达人', desc: '出行减排 ≥ 20kg', metric: 'cat:travel', threshold: 20 },
  { id: 'b_cycle', icon: 'ic_recycle', name: '循环大师', desc: '回收减排 ≥ 20kg', metric: 'cat:recycle', threshold: 20 }
]

export interface ShopItem {
  id: string
  icon: string
  tint: string
  name: string
  desc: string
  cost: number
  /** 兑换成功后跳转的目标页(空则不跳转,仅提示) */
  route: string
}

/** 岛币商城 */
export const SHOP_ITEMS: ShopItem[] = [
  { id: 's_badge', icon: 'ic_rank', tint: '#D97706', name: '限定徽章卡', desc: '专属身份徽章,收入你的徽章墙', cost: 100, route: 'pages/badge/BadgePage' },
  { id: 's_coupon', icon: 'ic_bill', tint: '#059669', name: '碳普惠平台券', desc: '岛币兑换平台权益券,权益码存入碳普惠券包', cost: 200, route: 'pages/carbon/CarbonPlusPage' },
  { id: 's_tree', icon: 'ic_leaf', tint: '#4E8FB8', name: '电子植树证书', desc: '以你的名义种下一棵真树', cost: 500, route: 'pages/certificate/CertificatePage' }
]

export interface Species {
  icon: string
  name: string
  desc: string
  /** 生态值解锁阈值 kg */
  threshold: number
}

/** 岛屿生态图鉴(随岛屿成长解锁) */
export const SPECIES: Species[] = [
  { icon: '🌊', name: '海浪', desc: '岛屿的原住民', threshold: 0 },
  { icon: '🌱', name: '新芽', desc: '第一抹绿意出现', threshold: 5 },
  { icon: '🌸', name: '野花', desc: '岛上开出了花', threshold: 10 },
  { icon: '🐦', name: '海鸟', desc: '开始有鸟儿停留', threshold: 25 },
  { icon: '🌲', name: '松林', desc: '树林渐成', threshold: 50 },
  { icon: '🐰', name: '野兔', desc: '小动物来安家', threshold: 80 },
  { icon: '🦌', name: '小鹿', desc: '森林的访客', threshold: 120 },
  { icon: '🐿️', name: '松鼠', desc: '森屿的精灵', threshold: 150 },
  { icon: '🐳', name: '鲸鱼', desc: '海域生态复苏', threshold: 250 },
  { icon: '🦋', name: '蝴蝶群', desc: '万物共生', threshold: 400 }
]
