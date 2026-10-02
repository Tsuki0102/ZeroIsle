import { common } from '@kit.AbilityKit'
import { emitter } from '@kit.BasicServicesKit'
import display from '@ohos.display'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { Database, Summary } from '../../data/Database'
import { FactorLibrary } from '../../data/FactorLibrary'
import { POINTS_PER_KG } from '../../model/Models'
import { LabStrip } from '../../components/MiniScenes'

/** 通勤方式的碳因子(与因子库口径一致) */
interface CommuteMode {
  key: string
  name: string
  icon: string
  factor: number
  factorId: string
}

const COMMUTE_MODES: CommuteMode[] = [
  { key: 'walk', name: '步行', icon: '🚶', factor: 0.20, factorId: 'T02' },
  { key: 'bike', name: '骑行', icon: '🚲', factor: 0.20, factorId: 'T01' },
  { key: 'bus', name: '公交', icon: '🚌', factor: 0.10, factorId: 'T03' },
  { key: 'metro', name: '地铁', icon: '🚇', factor: 0.13, factorId: 'T04' },
  { key: 'car', name: '驾车', icon: '🚗', factor: 0.20, factorId: '' } // 驾车排放口径≈0.2kg/km(与 T01/T02 减排因子同源),不参与入库
]

/** 本模块录入来源标记(用于统计本台战果与明细页溯源) */
const LAB_SOURCE: string = '碳知实验室'

interface LabArticle {
  id: string
  title: string
  category: string
  minutes: number
  body: string
}

const ARTICLES: LabArticle[] = [
  {
    id: 'a1',
    title: '碳达峰与碳中和,有什么不同?',
    category: '双碳基础',
    minutes: 3,
    body: '碳达峰,是指二氧化碳排放总量达到历史最高值后进入下降通道——好比爬到山顶。我国承诺在 2030 年前实现碳达峰。\n碳中和,则是排放的二氧化碳与植树造林、碳捕集等吸收的量相互抵消,实现"净零排放"——好比下山后把脚印全部抹平。我国承诺 2060 年前实现碳中和。\n两个时间点,一个管"增量见顶",一个管"存量归零"。对我们每个人来说,双碳不是宏大叙事:你少开一次车、光盘一餐饭,都是在为国家承诺的兑现投票。'
  },
  {
    id: 'a2',
    title: '1 度电 = 多少碳?',
    category: '互动计算器',
    minutes: 2,
    body: '按全国电网平均排放因子,每消耗 1 度电约对应 0.57 kg CO₂e。\n这意味着:一台 1.5 匹空调调高 1℃ 运行 8 小时,约省电 0.9 度 ≈ 减排 0.5 kg;宿舍彻底关闭待机电器一晚,约省 0.09 度。\n别小看这些数字:全国高校宿舍如果每间每天省 1 度电,一年下来减少的碳排放相当于多种下数十万棵树。这就是"宿舍节电挑战"背后的真实分量。'
  },
  {
    id: 'a3',
    title: '为什么少吃一顿肉 ≈ 种半棵树?',
    category: '低碳生活',
    minutes: 3,
    body: '生产 1 kg 牛肉的碳足迹约 27 kg CO₂e,是同等重量蔬菜的数十倍。一份普通肉食餐的碳足迹约 1.5-2 kg,而素食餐仅 0.5 kg 左右——差值接近 1 kg CO₂e。\n一棵树一年大约固碳 10 kg。也就是说,每周 5 天选择素食晚餐,一年累积的减排量约等于种下半棵树。\n不是要求人人吃素,而是"有意识地选择":每周一顿素,就是给岛屿种下一片叶子。'
  },
  {
    id: 'a4',
    title: '快递纸箱的第二次生命',
    category: '资源循环',
    minutes: 2,
    body: '每回收 1 kg 废纸,可避免约 1.5 kg CO₂e 排放——再生纸比原生纸少消耗约 60% 的能源与水。\n一个标准快递箱约 0.3 kg,校园快递站每天拆掉的纸箱数以千计。把它们投进回收箱而不是垃圾桶,是大学生最容易做到的低碳行为之一。\n在零屿里记录"回收纸张",系统会按这个口径为你的岛屿积累生态值。'
  },
  {
    id: 'a5',
    title: '读懂国家双碳"1+N"政策体系',
    category: '双碳政策',
    minutes: 3,
    body: '"1"是碳达峰碳中和顶层设计文件,"N"是能源、工业、交通、建筑等重点领域的实施方案与支撑保障政策,共同构成国家双碳工作的"四梁八柱"。\n几个关键节点:2030 年前实现碳达峰,2060 年前实现碳中和;全国碳排放权交易市场已覆盖电力、钢铁、水泥等重点行业;"十四五"期间单位 GDP 能耗与碳排放持续下降。\n和我们最相关的,是绿色出行、节能降碳、循环利用这些生活方式政策的落地——校园里的每一次骑行、每一餐光盘,都是政策链条最末端的真实行动。'
  },
  {
    id: 'a6',
    title: '碳普惠:让个人减碳"看得见、能变现"',
    category: '双碳政策',
    minutes: 2,
    body: '碳普惠是面向个人、社区和小微企业的低碳行为量化激励机制:把乘坐公交、节约用电、旧物回收等减碳量折算成"碳积分",再兑换商品或权益。\n国家《促进绿色消费实施方案》明确提出建立"碳普惠"等公众参与机制;广东、北京、上海、武汉等地的碳普惠平台已让数百万人用减碳量换来公交券、消费折扣。\n零屿的「碳普惠平台」页,就是这套机制在你手机上的预演:本地记账 → 同步积分 → 兑换权益,让每一克减碳都被看见。'
  },
  {
    id: 'a7',
    title: '食堂光盘的碳账本',
    category: '校园行动',
    minutes: 2,
    body: '一份大学食堂套餐从种植、运输、加工到上桌,平均携带 1.5-2.5 kg CO₂e 的碳足迹;被倒掉的那部分,碳已经排出去了,却没有产生任何营养价值。\n按每餐浪费 0.1 kg 食物估算,一顿光盘约减排 0.25 kg。听起来不多,但如果一个 2 万人的校园,人均每天有一餐做到光盘,一年减少的碳排放约 1825 吨——相当于种下 18 万棵树。\n光盘不是"穷讲究",而是把已经付出的碳真正用上。'
  },
  {
    id: 'a8',
    title: '共享单车:最后一公里的减碳账',
    category: '校园行动',
    minutes: 2,
    body: '校园里最常见的低碳场景,是宿舍到教学楼的那 1-2 公里。这段路如果开车(或打车),按 0.2 kg/km 计,单程约排放 0.2-0.4 kg CO₂e;换成骑车则接近零排放。\n一个人每天往返一次、每学年按 200 天算,累积减排约 80-160 kg CO₂e——差不多是 8-16 棵树一年的固碳量。\n零屿的口径与这里一致:骑行 1 公里按 0.2 kg 计入生态值。别小看这点数字,它乘以人数与天数,就是校园减排的真实分量。'
  },
  {
    id: 'a9',
    title: '垃圾分类为什么能减碳?',
    category: '资源循环',
    minutes: 2,
    body: '垃圾的碳排放主要来自两部分:一是填埋后产生的甲烷(温室效应是二氧化碳的 25 倍以上),二是本可回收的物料被重新生产时消耗的能源。\n把塑料瓶、废纸、金属分出来回收,等于用"再生料"替代"原生料"。以 PET 塑料瓶为例,再生料比原生料节能约 70%,每个瓶子约减少 0.05 kg CO₂e。\n分类的意义不是"更整齐",而是让物料重新进入生产循环——你投放的那一下,省下的是整条产业链的能源。'
  },
  {
    id: 'a10',
    title: '旧手机别扔:电子垃圾的碳代价',
    category: '资源循环',
    minutes: 3,
    body: '一部智能手机的生产环节约排放 50-80 kg CO₂e,其中芯片与屏幕占了大头,远高于它开机使用的耗电。也就是说,把手机多用一年,比换新机能省下数十公斤碳。\n当设备确实需要退役时,正规回收能把它拆解出的金、银、铜、稀土重新利用。据公开研究,回收 1 吨废旧手机主板可提取的金属价值远高于同等重量的矿石,同时避免重金属污染土壤与地下水。\n在零屿里,"回收小家电/旧物转卖"正是按这个口径折算减排的。'
  },
  {
    id: 'a11',
    title: '碳足迹的三个范围:Scope 1/2/3 入门',
    category: '双碳基础',
    minutes: 3,
    body: '国际通行的碳足迹核算把排放分成三个范围:范围一(直接排放)指自有设施燃烧化石燃料产生的排放,比如开车烧油;范围二(间接排放)指外购电力和热力带来的排放,比如你用的每一度电;范围三(其他间接排放)覆盖上下游供应链,比如你买的食品在种植、运输、包装环节的排放。\n对企业而言,范围三往往占比最大;对个人而言,日常减排大多落在范围二(节电)与范围三(饮食、出行、购物、回收)。\n理解这套划分,你就知道为什么"少吃一顿肉"和"关掉待机电器"会出现在同一张清单里——它们只是落在不同范围。'
  },
  {
    id: 'a12',
    title: '碳标签与绿色消费:包装上的数字意味着什么',
    category: '双碳政策',
    minutes: 3,
    body: '碳标签是把商品全生命周期的碳排放量标注在包装上,让消费者能像看热量表一样看碳。英国、日本、韩国等地已推行多年,国内部分食品、日化与电子产品也开始试点。\n碳标签的价值在于"把看不见的成本显性化":同样两瓶饮料,如果碳标签差了一倍,那背后是原料、运输与包装方式的差异。它能引导企业主动降碳,也让"绿色消费"从口号变成可比较的选择。\n国家《促进绿色消费实施方案》提出推广绿色产品认证与碳足迹标识。你每一次有依据的选择,都是在给低碳产品投票。'
  }
]

/** 知识库插画清单(rawfile/knowledge/kb_<id>.jpg);新增插画后在此补 id */
const KB_IMG_IDS: string[] = ['a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9', 'a10', 'a11', 'a12']

/** 碳小知识·每日一签(按日期轮换,点击可换下一条) */
const DAILY_TIPS: string[] = [
  '空调调高 1℃,运行 8 小时约减排 0.5 kg CO₂e',
  '生产 1 个塑料瓶约排放 0.08 kg CO₂e,自带水杯一年能省下上百个',
  '骑行通勤每公里比驾车减排 0.2 kg,一年骑 500 公里 ≈ 种 10 棵树',
  '少点一次外卖,连包装带配送约减排 0.35 kg CO₂e',
  '回收 1 公斤旧衣物 ≈ 减排 3.6 kg CO₂e,相当于少开 18 公里车',
  '待机电器约占家庭用电 5%-10%,睡前拔插头是最省心的减碳',
  '一头牛一年排放约 3 吨 CO₂e,每周一顿素食就是实实在在的减排',
  '1 吨水从生产到污水处理约折算 0.3 kg CO₂e,一水多用最划算',
  '双面打印一张 A4 纸约减排 4 克,全校一年能省出一座小森林',
  '一棵树一年固碳约 10 kg——你攒下的每一枚岛币,都在认养它'
]

/** 碳知实验室「验」:知识 × 互动计算器,可一键记录 */
@Component
export struct LabPage {
  @State expandedId: string = ''
  @State calcMode: string = 'bike'
  @State calcKm: string = '5'
  @State meals: string = '5'
  @State kwh: string = '10'
  @State tipIdx: number = 0
  // 知识库:分类筛选 + 收藏 + 关键词搜索
  @State artCat: string = '全部'
  @State artQuery: string = ''
  @State favIds: string[] = []
  // 仪器面板:本模块战果(来源=碳知实验室)
  @State labCount: number = 0
  @State labCo2: number = 0
  @State labPoints: number = 0
  // 仪器面板:本机碳账本总览(全来源)
  @State acctCount: number = 0
  @State acctCo2: number = 0
  // 响应式:平板/大屏(≥600vp)走双列布局
  @State isWide: boolean = false
  // 记录反馈:每台仪器各自持有一条"已记入"时间戳
  @State savedCommute: string = ''
  @State savedKwh: string = ''
  @State savedMeals: string = ''

  private readonly onDataChanged: () => void = () => {
    this.loadLabStats()
  }

  aboutToAppear(): void {
    const now = new Date()
    const start = new Date(now.getFullYear(), 0, 0)
    const day: number = Math.floor((now.getTime() - start.getTime()) / 86400000)
    this.tipIdx = day % DAILY_TIPS.length
    const ctx = getContext(this) as common.UIAbilityContext
    Database.kvGet(ctx, 'lab_fav', '').then((raw: string) => {
      try {
        const arr = JSON.parse(raw) as Array<string>
        if (Array.isArray(arr)) {
          this.favIds = arr
        }
      } catch (err) {
        this.favIds = []
      }
    })
    this.loadLabStats()
    emitter.on({ eventId: EVT_DATA_CHANGED }, this.onDataChanged)
    try {
      const d: display.Display = display.getDefaultDisplaySync()
      this.isWide = (d.width / d.densityPixels) >= 600
    } catch (err) {
      // 屏幕信息不可用时按单列布局
    }
  }

  aboutToDisappear(): void {
    emitter.off(EVT_DATA_CHANGED, this.onDataChanged)
  }

  /** 仪器面板数据:本机账本总览 + 本台贡献 */
  private loadLabStats(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    Database.summaryBySource(ctx, '碳知实验室').then((s: Summary) => {
      this.labCount = s.count
      this.labCo2 = s.totalCo2
      this.labPoints = s.totalPoints
    })
    Database.summary(ctx).then((s: Summary) => {
      this.acctCount = s.count
      this.acctCo2 = s.totalCo2
    })
  }

  private nowStamp(): string {
    const d = new Date()
    const hh: string = d.getHours() < 10 ? '0' + d.getHours() : '' + d.getHours()
    const mi: string = d.getMinutes() < 10 ? '0' + d.getMinutes() : '' + d.getMinutes()
    return `${hh}:${mi}`
  }

  /** 知识库分类:全部 + 收藏 + 文章中实际出现的分类 */
  private artCats(): string[] {
    const list: string[] = ['全部', '★ 收藏']
    for (const a of ARTICLES) {
      if (!list.includes(a.category)) {
        list.push(a.category)
      }
    }
    return list
  }

  private visibleArticles(): LabArticle[] {
    let list: LabArticle[] = ARTICLES
    if (this.artCat === '★ 收藏') {
      list = ARTICLES.filter((a: LabArticle) => this.favIds.includes(a.id))
    } else if (this.artCat !== '全部') {
      list = ARTICLES.filter((a: LabArticle) => a.category === this.artCat)
    }
    const q: string = this.artQuery.trim()
    if (q === '') {
      return list
    }
    return list.filter((a: LabArticle) =>
      a.title.includes(q) || a.body.includes(q) || a.category.includes(q))
  }

  /** 分类配图(结构图标 SVG) */
  private artIcon(cat: string): string {
    if (cat === '双碳政策') {
      return 'ic_bank'
    }
    if (cat === '双碳基础') {
      return 'ic_book'
    }
    if (cat === '互动计算器') {
      return 'ic_calc'
    }
    if (cat === '低碳生活') {
      return 'ic_leaf'
    }
    if (cat === '资源循环') {
      return 'ic_recycle'
    }
    if (cat === '校园行动') {
      return 'ic_bike'
    }
    return 'ic_book'
  }

  private toggleFav(id: string): void {
    const next: string[] = []
    let removed: boolean = false
    for (const x of this.favIds) {
      if (x === id) {
        removed = true
      } else {
        next.push(x)
      }
    }
    if (!removed) {
      next.push(id)
    }
    this.favIds = next
    const ctx = getContext(this) as common.UIAbilityContext
    Database.kvSet(ctx, 'lab_fav', JSON.stringify(next)).then(() => {
      toast(removed ? '已取消收藏' : '已收藏,可在「★ 收藏」分类查看')
    })
  }

  private mode(): CommuteMode {
    for (const m of COMMUTE_MODES) {
      if (m.key === this.calcMode) {
        return m
      }
    }
    return COMMUTE_MODES[1]
  }

  private km(): number {
    const v: number = parseFloat(this.calcKm)
    return isNaN(v) ? 0 : v
  }

  private commuteCo2(): number {
    return this.km() * this.mode().factor
  }

  /** 节电减排(因子取 E01,与入库同源,避免硬编码 0.57) */
  private energyCo2(): number {
    const n: number = parseFloat(this.kwh)
    return (isNaN(n) ? 0 : n) * FactorLibrary.byId('E01').factor
  }

  /** 光盘减排(因子取 F01,与入库同源) */
  private mealCo2(): number {
    const n: number = parseFloat(this.meals)
    return (isNaN(n) ? 0 : n) * FactorLibrary.byId('F01').factor
  }

  private saveCommute(): void {
    const m = this.mode()
    if (m.key === 'car' || this.km() <= 0) {
      toast('驾车不产生减排,选个绿色方式并输入距离吧')
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    // 来源标记为模块名:便于「本台战果」统计与明细页溯源
    Database.insertRecord(ctx, m.factorId, this.km(), LAB_SOURCE, '通勤碳计算器').then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      this.savedCommute = this.nowStamp()
      toast(`已记录 ${m.name}${this.km()} 公里,岛屿在生长!`)
    })
  }

  private saveMeals(): void {
    const n: number = parseFloat(this.meals)
    if (isNaN(n) || n <= 0) {
      toast('先输入光盘餐数(大于 0)')
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    Database.insertRecord(ctx, 'F01', n, LAB_SOURCE, '光盘打卡器').then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      this.savedMeals = this.nowStamp()
      toast(`已记录光盘 ${n} 餐!`)
    })
  }

  private saveKwh(): void {
    const n: number = parseFloat(this.kwh)
    if (isNaN(n) || n <= 0) {
      toast('先输入省电度数(大于 0)')
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    Database.insertRecord(ctx, 'E01', n, LAB_SOURCE, '节电换算器').then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      this.savedKwh = this.nowStamp()
      toast(`已记录节电 ${n} 度!`)
    })
  }

  // ==================== 设计系统:统一交互组件 ====================

  /**
   * Hero 仪器面板:画布实验台 + 标题 + 账本总览指标
   * 说明:本页所有区块组件一律采用「无参 @Builder」——ArkUI 中带参 Builder 为按值传递、
   * 不会随状态变量刷新(实测:切换出行方式后选中态/结果/按钮均不更新),无参 Builder 等价于
   * 内联 UI,状态读取可正常驱动刷新。
   */
  /**
   * 插画动图横幅 + 左下「仪器读数牌」
   * 与「析」「营」同属玻璃浮层语言,但形态刻意区分:圆角矩形(12,非胶囊 999)
   * + 左侧绿色读数条,内部文字与「析」保持同一写法(累计 X kg CO₂e / N 笔记录)
   */
  @Builder
  heroBanner() {
    Stack({ alignContent: Alignment.BottomStart }) {
      LabStrip()
      Row({ space: 8 }) {
        Text(`实验室累计 ${this.acctCo2.toFixed(1)} kg CO₂e`)
          .fontSize(12).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .fontFamily(ZeroTheme.fontNum)
        Text(`本台 ${this.acctCount} 笔`)
          .fontSize(10).fontColor($r('app.color.text_sub'))
      }
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor('rgba(255,255,255,0.8)')
      .borderRadius(999)
      .margin({ left: 12, bottom: 10 })
    }
    .width('100%')
    .height(128)
    .borderRadius(ZeroTheme.radiusL)
    .clip(true)
    .margin({ top: 12 })
  }



  /** 区块标题:工具台(右侧仅在本台有战果时显示一句话) */
  @Builder
  toolSectionHead() {
    Row({ space: 6 }) {
      Image($rawfile('icons/ic_calc.svg')).width(14).height(14).fillColor($r('app.color.primary'))
      Text('工具台').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Blank()
      if (this.labCount > 0) {
        Text(`本台 ${this.labCount} 笔`).fontSize(10).fontColor($r('app.color.text_sub'))
      }
    }
    .width('100%')
    .margin({ top: 18 })
  }

  /** 区块标题:知识库(右侧仅显示篇数) */
  @Builder
  knowSectionHead() {
    Row({ space: 6 }) {
      Image($rawfile('icons/ic_book.svg')).width(14).height(14).fillColor($r('app.color.primary'))
      Text('知识库').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
      Blank()
      Text(`${ARTICLES.length} 篇 · 收藏 ${this.favIds.length}`).fontSize(10).fontColor($r('app.color.text_sub'))
    }
    .width('100%')
    .margin({ top: 18 })
  }

  /**
   * 胶囊选择器样式(仪器内模式 / 知识库分类统一):返回统一修饰后的 Text
   * 以无参 Builder 形式各自内联在对应区块中,保证选中态随状态刷新
   */

  // ==================== 三台实验仪器 ====================

  @Builder
  commuteBody() {
    Column() {
      Row({ space: 6 }) {
        Image($rawfile('icons/ic_bike.svg')).width(14).height(14).fillColor($r('app.color.primary'))
        Text('通勤').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        if (this.mode().key === 'car') {
          Text('不计减排').fontSize(11).fontColor($r('app.color.danger'))
        } else {
          Text(this.commuteCo2().toFixed(2))
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
            .fontFamily(ZeroTheme.fontNum)
          Text(' kg').fontSize(10).fontColor($r('app.color.text_sub')).margin({ bottom: 2 })
          Text(`+${Math.round(this.commuteCo2() * POINTS_PER_KG)} 币`)
            .fontSize(11).fontWeight(FontWeight.Bold).fontColor($r('app.color.gold_deep'))
            .margin({ left: 8, bottom: 2 })
        }
      }
      .width('100%')

      Row({ space: 6 }) {
        ForEach(COMMUTE_MODES, (m: CommuteMode) => {
          Text(m.name)
            .fontSize(11)
            .fontColor(this.calcMode === m.key ? $r('app.color.text_light') : $r('app.color.text_main'))
            .padding({ left: 11, right: 11, top: 5, bottom: 5 })
            .backgroundColor(this.calcMode === m.key ? $r('app.color.primary') : $r('app.color.bg'))
            .borderRadius(999)
            .clickEffect({ level: ClickEffectLevel.LIGHT })
            .onClick(() => {
              this.calcMode = m.key
            })
        }, (m: CommuteMode) => m.key)
      }
      .width('100%')
      .margin({ top: 10 })

      Row({ space: 8 }) {
        TextInput({ text: this.calcKm })
          .type(InputType.NUMBER_DECIMAL)
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
          .height(36).width(64)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.bg'))
          .borderRadius(10)
          .onChange((v: string) => {
            this.calcKm = v
          })
        Text('公里').fontSize(12).fontColor($r('app.color.text_sub'))
        Blank()
        Button(this.mode().key === 'car' ? '换方式' : '记入')
          .fontSize(12).height(34).width(80)
          .backgroundColor(this.mode().key !== 'car' && this.km() > 0
            ? $r('app.color.primary') : $r('app.color.bg'))
          .fontColor(this.mode().key !== 'car' && this.km() > 0
            ? $r('app.color.text_light') : $r('app.color.text_sub'))
          .borderRadius(ZeroTheme.radiusPill)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .enabled(this.mode().key !== 'car' && this.km() > 0)
          .onClick(() => {
            this.saveCommute()
          })
      }
      .width('100%')
      .margin({ top: 10 })

      if (this.savedCommute !== '') {
        Text(`已记入 · ${this.savedCommute}`)
          .fontSize(10).fontColor($r('app.color.life_deep'))
          .margin({ top: 6 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(ZeroTheme.padM)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(ZeroTheme.radiusL)
    .border({ width: 1, color: $r('app.color.hairline') })
    .margin({ top: 10 })
  }

  @Builder
  energyBody() {
    Column() {
      Row({ space: 6 }) {
        Image($rawfile('icons/ic_bolt.svg')).width(14).height(14).fillColor($r('app.color.primary'))
        Text('节电').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Text(this.energyCo2().toFixed(2))
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
          .fontFamily(ZeroTheme.fontNum)
        Text(' kg').fontSize(10).fontColor($r('app.color.text_sub')).margin({ bottom: 2 })
        Text(`+${Math.round(this.energyCo2() * POINTS_PER_KG)} 币`)
          .fontSize(11).fontWeight(FontWeight.Bold).fontColor($r('app.color.gold_deep'))
          .margin({ left: 8, bottom: 2 })
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.kwh })
          .type(InputType.NUMBER_DECIMAL)
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
          .height(36).width(64)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.bg'))
          .borderRadius(10)
          .onChange((v: string) => {
            this.kwh = v
          })
        Text('度').fontSize(12).fontColor($r('app.color.text_sub'))
        Blank()
        Button('记入')
          .fontSize(12).height(34).width(80)
          .backgroundColor(this.energyCo2() > 0 ? $r('app.color.primary') : $r('app.color.bg'))
          .fontColor(this.energyCo2() > 0 ? $r('app.color.text_light') : $r('app.color.text_sub'))
          .borderRadius(ZeroTheme.radiusPill)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .enabled(this.energyCo2() > 0)
          .onClick(() => {
            this.saveKwh()
          })
      }
      .width('100%')
      .margin({ top: 10 })

      if (this.savedKwh !== '') {
        Text(`已记入 · ${this.savedKwh}`)
          .fontSize(10).fontColor($r('app.color.life_deep'))
          .margin({ top: 6 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(ZeroTheme.padM)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(ZeroTheme.radiusL)
    .border({ width: 1, color: $r('app.color.hairline') })
    .margin({ top: 10 })
  }

  @Builder
  mealBody() {
    Column() {
      Row({ space: 6 }) {
        Image($rawfile('icons/ic_bowl.svg')).width(14).height(14).fillColor($r('app.color.primary'))
        Text('光盘').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Text(this.mealCo2().toFixed(2))
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
          .fontFamily(ZeroTheme.fontNum)
        Text(' kg').fontSize(10).fontColor($r('app.color.text_sub')).margin({ bottom: 2 })
        Text(`+${Math.round(this.mealCo2() * POINTS_PER_KG)} 币`)
          .fontSize(11).fontWeight(FontWeight.Bold).fontColor($r('app.color.gold_deep'))
          .margin({ left: 8, bottom: 2 })
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.meals })
          .type(InputType.NUMBER_DECIMAL)
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary'))
          .height(36).width(64)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.bg'))
          .borderRadius(10)
          .onChange((v: string) => {
            this.meals = v
          })
        Text('餐').fontSize(12).fontColor($r('app.color.text_sub'))
        Blank()
        Button('记入')
          .fontSize(12).height(34).width(80)
          .backgroundColor(this.mealCo2() > 0 ? $r('app.color.primary') : $r('app.color.bg'))
          .fontColor(this.mealCo2() > 0 ? $r('app.color.text_light') : $r('app.color.text_sub'))
          .borderRadius(ZeroTheme.radiusPill)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .enabled(this.mealCo2() > 0)
          .onClick(() => {
            this.saveMeals()
          })
      }
      .width('100%')
      .margin({ top: 10 })

      if (this.savedMeals !== '') {
        Text(`已记入 · ${this.savedMeals}`)
          .fontSize(10).fontColor($r('app.color.life_deep'))
          .margin({ top: 6 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(ZeroTheme.padM)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(ZeroTheme.radiusL)
    .border({ width: 1, color: $r('app.color.hairline') })
    .margin({ top: 10 })
  }

  /** 每日一签(轻量小卡:标签 + 一行内容) */
  @Builder
  tipCard() {
    Column({ space: 3 }) {
      Row() {
        Text('每日一签').fontSize(11).fontWeight(FontWeight.Bold).fontColor($r('app.color.life_deep'))
        Blank()
        Text('换一条')
          .fontSize(10).fontColor($r('app.color.text_sub'))
          .padding({ left: 8, right: 2, top: 2, bottom: 2 })
          .onClick(() => {
            this.tipIdx = (this.tipIdx + 1) % DAILY_TIPS.length
          })
      }
      .width('100%')

      Text(DAILY_TIPS[this.tipIdx % DAILY_TIPS.length])
        .fontSize(12).fontColor($r('app.color.text_main')).lineHeight(18)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: ZeroTheme.padM, right: ZeroTheme.padM, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.bg_deep'))
    .borderRadius(ZeroTheme.radiusL)
    .margin({ top: 10 })
  }

  /** 知识库分类 → 主题 emoji(头图用) */
  private catEmoji(category: string): string {
    if (category === '双碳政策') {
      return '🏛️'
    }
    if (category === '双碳基础') {
      return '⛰️'
    }
    if (category === '低碳生活') {
      return '🥗'
    }
    if (category === '资源循环') {
      return '♻️'
    }
    if (category === '校园行动') {
      return '🚲'
    }
    if (category === '互动计算器') {
      return '🧮'
    }
    return '🌿'
  }

  /** 文章头图:优先插画(knowledge/kb_<id>.jpg),回退分类渐变横幅 */
  @Builder
  artBanner(a: LabArticle) {
    if (KB_IMG_IDS.includes(a.id)) {
      Image($rawfile(`knowledge/kb_${a.id}.jpg`))
        .width('100%')
        .height(88)
        .objectFit(ImageFit.Cover)
        .borderRadius(ZeroTheme.radiusM)
        .clip(true)
        .accessibilityText(`${a.category} 科普文章头图`)
    } else {
      this.gradientBanner(a.category)
    }
  }

  /** 分类渐变横幅(零素材兜底,深浅色自适配) */
  @Builder
  gradientBanner(category: string) {
    Stack({ alignContent: Alignment.Start }) {
      Column()
        .width('100%')
        .height(88)
        .linearGradient({
          angle: 135,
          colors: [[$r('app.color.primary'), 0.0], [$r('app.color.primary_deep'), 1.0]]
        })
      Column()
        .width(120).height(120).borderRadius(60)
        .backgroundColor('rgba(255,255,255,0.08)')
        .margin({ left: -34, top: -30 })
      Column()
        .width(70).height(70).borderRadius(35)
        .backgroundColor('rgba(251,191,36,0.14)')
        .margin({ left: 240, top: 46 })
      Row({ space: 10 }) {
        Text(this.catEmoji(category)).fontSize(30)
        Column({ space: 3 }) {
          Text('零屿科普 · 图文解读')
            .fontSize(9).fontColor('rgba(255,255,255,0.8)')
          Text(category)
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_light'))
        }
        .alignItems(HorizontalAlign.Start)
      }
      .padding({ left: 16 })
    }
    .width('100%')
    .height(88)
    .borderRadius(ZeroTheme.radiusM)
    .clip(true)
    .accessibilityText(`${category} 科普文章头图`)
  }

  /** 知识卡列表(无参:随分类 / 搜索 / 展开 / 收藏状态刷新) */
  @Builder
  articleList() {
    ForEach(this.visibleArticles(), (a: LabArticle) => {
      Column() {
        Row() {
          Image($rawfile(`icons/${this.artIcon(a.category)}.svg`))
            .width(14).height(14).fillColor($r('app.color.primary'))
          Text(a.category)
            .fontSize(9).fontColor($r('app.color.primary'))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor($r('app.color.primary_light'))
            .borderRadius(6)
            .margin({ left: 6 })
          Blank()
          Text(this.favIds.includes(a.id) ? '★' : '☆')
            .fontSize(16)
            .fontColor(this.favIds.includes(a.id) ? $r('app.color.gold_deep') : $r('app.color.text_sub'))
            .padding({ left: 10, right: 6, top: 2, bottom: 2 })
            .clickEffect({ level: ClickEffectLevel.LIGHT })
            .onClick(() => {
              this.toggleFav(a.id)
            })
          Text(`${a.minutes} 分钟`).fontSize(9).fontColor($r('app.color.text_sub'))
          Text(this.expandedId === a.id ? '⌃' : '⌄')
            .fontSize(11).fontColor($r('app.color.text_sub'))
            .margin({ left: 6, right: 4 })
        }
        .width('100%')

        Text(a.title)
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 6 })

        if (this.expandedId === a.id) {
          this.artBanner(a)
          Text(a.body)
            .fontSize(13)
            .fontColor($r('app.color.text_main'))
            .lineHeight(21)
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .backgroundColor($r('app.color.bg'))
            .borderRadius(ZeroTheme.radiusM)
            .border({ width: { left: 2 }, color: $r('app.color.primary') })
            .margin({ top: 8 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: ZeroTheme.padM, right: ZeroTheme.padM, top: 13, bottom: 13 })
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(ZeroTheme.radiusL)
      .border({ width: 1, color: $r('app.color.hairline') })
      .margin({ top: 8 })
      .onClick(() => {
        this.expandedId = this.expandedId === a.id ? '' : a.id
      })
    }, (a: LabArticle) => a.id)
  }

  /** 知识库搜索框(无参) */
  @Builder
  searchBox() {
    Row({ space: 6 }) {
      Image($rawfile('icons/ic_search.svg')).width(14).height(14).fillColor($r('app.color.text_sub'))
      TextInput({ placeholder: '搜索知识库' })
        .fontSize(12)
        .height(34)
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .placeholderColor($r('app.color.text_sub'))
        .onChange((v: string) => {
          this.artQuery = v
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(ZeroTheme.radiusPill)
    .border({ width: 1, color: $r('app.color.hairline') })
    .margin({ top: 10 })
  }

  /** 知识库分类筛选(无参:选中态随状态刷新) */
  @Builder
  catChips() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.artCats(), (c: string) => {
          Text(c)
            .fontSize(11)
            .fontColor(this.artCat === c ? $r('app.color.text_light') : $r('app.color.text_main'))
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(this.artCat === c ? $r('app.color.primary') : $r('app.color.card_bg'))
            .border({
              width: 1,
              color: this.artCat === c ? $r('app.color.primary') : $r('app.color.hairline')
            })
            .borderRadius(999)
            .clickEffect({ level: ClickEffectLevel.LIGHT })
            .onClick(() => {
              this.artCat = c
              this.expandedId = ''
            })
        }, (c: string) => c)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .margin({ top: 10 })
    .align(Alignment.Start)
  }

  /** 知识库空态(无参:文案随搜索 / 分类变化) */
  @Builder
  articleEmpty() {
    Column({ space: 6 }) {
      Image($rawfile('icons/ic_search.svg')).width(24).height(24).fillColor($r('app.color.text_sub'))
      Text(this.artQuery.trim() !== '' ? '没有匹配的文章' : '还没有收藏')
        .fontSize(12).fontColor($r('app.color.text_sub'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding({ top: 26, bottom: 26 })
  }

  build() {
    Column() {
      // 页头:与其他三个 Tab 保持一致(22 号加粗 · 左对齐 · 同一内距)
      Text('碳知实验室')
        .fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        .width('100%')
        .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      Scroll() {
        Column() {
          Column() {
            // ===== 插画动图(纯画布,无遮挡) =====
            this.heroBanner()

            // ===== 工具台 =====
            this.toolSectionHead()
            this.commuteBody()

            if (this.isWide) {
              Row({ space: 12 }) {
                Column() {
                  this.energyBody()
                }.layoutWeight(1)
                Column() {
                  this.mealBody()
                }.layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            } else {
              this.energyBody()
              this.mealBody()
            }

            // ===== 每日一签 =====
            this.tipCard()

            // ===== 低碳知识库 =====
            this.knowSectionHead()
            this.searchBox()
            this.catChips()

            if (this.visibleArticles().length === 0) {
              this.articleEmpty()
            }

            this.articleList()

            // 页脚(一句话说明数据边界)
            Text('数据仅存本机 · 因子库内置')
              .fontSize(10).fontColor($r('app.color.text_sub'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 16, bottom: 12 })
          }
          .width(this.isWide ? '78%' : '100%')
        }
        .width('100%')
        .alignItems(this.isWide ? HorizontalAlign.Center : HorizontalAlign.Start)
        .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
  }
}
