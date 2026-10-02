import { FactorLibrary } from '../data/FactorLibrary'

/** 语义解析出的单条行为 */
export class ParsedItem {
  factorId: string = ''
  name: string = ''
  icon: string = ''
  amount: number = 1
  unit: string = ''
  co2Kg: number = 0
  points: number = 0
}

/** 解析结果:识别项 + 未识别片段 */
export class ParseResult {
  items: ParsedItem[] = []
  unmatched: string[] = []

  totalCo2(): number {
    let t: number = 0
    for (const it of this.items) {
      t += it.co2Kg
    }
    return t
  }

  totalPoints(): number {
    let t: number = 0
    for (const it of this.items) {
      t += it.points
    }
    return t
  }
}

interface AliasEntry {
  key: string
  factorId: string
}

/**
 * 端侧语义解析引擎(基线版:关键词别名 + 数量抽取)
 * 例:"骑车3公里,午餐光盘" → [骑行代替驾车×3km, 光盘行动×1餐]
 * 后续可升级分词/模糊匹配,不动上层接口
 */
export class SemanticParser {
  private static readonly ALIASES: AliasEntry[] = [
    { key: '骑行', factorId: 'T01' }, { key: '骑车', factorId: 'T01' },
    { key: '步行', factorId: 'T02' }, { key: '走路', factorId: 'T02' }, { key: '徒步', factorId: 'T02' },
    { key: '公交', factorId: 'T03' },
    { key: '地铁', factorId: 'T04' },
    { key: '拼车', factorId: 'T05' },
    { key: '新能源', factorId: 'T06' }, { key: '电车', factorId: 'T06' },
    { key: '少开车', factorId: 'T07' }, { key: '不开车', factorId: 'T07' },
    { key: '爬楼梯', factorId: 'T08' }, { key: '走楼梯', factorId: 'T08' },
    { key: '节约用电', factorId: 'E01' }, { key: '节电', factorId: 'E01' }, { key: '省电', factorId: 'E01' },
    { key: '随手关灯', factorId: 'E01' },
    { key: '空调', factorId: 'E02' },
    { key: '待机', factorId: 'E03' },
    { key: '淋浴', factorId: 'E04' },
    { key: '节约用水', factorId: 'W01' }, { key: '节水', factorId: 'W01' }, { key: '省水', factorId: 'W01' },
    { key: '一水多用', factorId: 'W02' },
    { key: '光盘', factorId: 'F01' },
    { key: '素食', factorId: 'F02' }, { key: '吃素', factorId: 'F02' },
    { key: '外卖', factorId: 'F03' },
    { key: '自带杯', factorId: 'F04' }, { key: '水杯', factorId: 'F04' },
    { key: '自带餐具', factorId: 'F05' }, { key: '饭盒', factorId: 'F05' },
    { key: '旧衣', factorId: 'R01' }, { key: '捐衣', factorId: 'R01' }, { key: '衣物回收', factorId: 'R01' },
    { key: '废纸', factorId: 'R02' }, { key: '纸箱', factorId: 'R02' }, { key: '回收纸', factorId: 'R02' },
    { key: '塑料瓶', factorId: 'R03' }, { key: '瓶子', factorId: 'R03' },
    { key: '易拉罐', factorId: 'R04' }, { key: '金属', factorId: 'R04' },
    { key: '二手', factorId: 'R05' }, { key: '闲置', factorId: 'R05' }, { key: '捐赠', factorId: 'R05' }, { key: '转卖', factorId: 'R05' },
    { key: '小家电', factorId: 'R06' },
    { key: '购物袋', factorId: 'H01' }, { key: '自带袋', factorId: 'H01' },
    { key: '垃圾分类', factorId: 'H02' },
    { key: '无纸化', factorId: 'H03' }, { key: '双面打印', factorId: 'H03' },
    { key: '过度包装', factorId: 'H04' }, { key: '简单包装', factorId: 'H04' },
    { key: '植树', factorId: 'H05' }, { key: '种树', factorId: 'H05' }, { key: '认养', factorId: 'H05' }
  ]

  /** 分隔符:中英文标点、连词、空白 */
  static parse(input: string): ParseResult {
    const result = new ParseResult()
    if (input.trim().length === 0) {
      return result
    }
    const clauses: string[] = input.split(/[,，、;；!！?？。.\s]+/)
    for (const raw of clauses) {
      const clause: string = raw.trim()
      if (clause.length === 0) {
        continue
      }
      let matchedId: string = ''
      for (const a of SemanticParser.ALIASES) {
        if (clause.includes(a.key)) {
          matchedId = a.factorId
          break
        }
      }
      if (matchedId === '') {
        result.unmatched.push(clause)
        continue
      }
      const amount: number = SemanticParser.extractAmount(clause, matchedId)
      const f = FactorLibrary.byId(matchedId)
      const item = new ParsedItem()
      item.factorId = f.id
      item.name = f.name
      item.icon = FactorLibrary.categoryIcon(f.categoryId)
      item.amount = amount
      item.unit = f.unit
      item.co2Kg = amount * f.factor
      item.points = Math.round(item.co2Kg * 10)
      result.items.push(item)
    }
    return result
  }

  /** 从子句抽取数量:阿拉伯数字 > 中文数字(含"十"组合与"半");无则默认 1 */
  private static extractAmount(clause: string, factorId: string): number {
    const m: RegExpMatchArray | null = clause.match(/(\d+(?:\.\d+)?)/)
    if (m !== null) {
      const v: number = parseFloat(m[1])
      if (!isNaN(v) && v > 0) {
        return SemanticParser.applyTimeUnit(clause, factorId, v)
      }
    }
    const c: RegExpMatchArray | null = clause.match(/[一二两三四五六七八九十半]+/)
    if (c !== null) {
      const v: number = SemanticParser.cnToNum(c[0])
      if (v > 0) {
        return SemanticParser.applyTimeUnit(clause, factorId, v)
      }
    }
    return 1
  }

  /** 中文数字串转数值:两=2、十=10、二十=20、二十五=25、半=0.5 */
  private static cnToNum(s: string): number {
    if (s === '半') {
      return 0.5
    }
    if (s === '十') {
      return 10
    }
    const idx: number = s.indexOf('十')
    if (idx >= 0) {
      const tens: number = idx > 0 ? SemanticParser.cnDigit(s.charAt(idx - 1)) : 1
      const ones: number = idx + 1 < s.length ? SemanticParser.cnDigit(s.charAt(idx + 1)) : 0
      return tens * 10 + ones
    }
    return SemanticParser.cnDigit(s)
  }

  private static cnDigit(ch: string): number {
    if (ch === '一') {
      return 1
    }
    if (ch === '二' || ch === '两') {
      return 2
    }
    if (ch === '三') {
      return 3
    }
    if (ch === '四') {
      return 4
    }
    if (ch === '五') {
      return 5
    }
    if (ch === '六') {
      return 6
    }
    if (ch === '七') {
      return 7
    }
    if (ch === '八') {
      return 8
    }
    if (ch === '九') {
      return 9
    }
    if (ch === '半') {
      return 0.5
    }
    return 0
  }

  private static strToNum(s: string): number {
    if (/^\d/.test(s)) {
      return parseFloat(s)
    }
    return SemanticParser.cnToNum(s)
  }

  /**
   * 时间表述归一:「骑车30分钟/骑行2小时/步行半小时」→ 按均速折算公里。
   * 仅对以公里计的出行因子(T01 骑行 / T02 步行)生效;子句已含"公里"时不重复换算。
   */
  private static applyTimeUnit(clause: string, factorId: string, raw: number): number {
    if (factorId !== 'T01' && factorId !== 'T02') {
      return raw
    }
    if (clause.includes('公里')) {
      return raw
    }
    const tm: RegExpMatchArray | null =
      clause.match(/(\d+(?:\.\d+)?|[一二两三四五六七八九十半]+)\s*(小时|分钟)/)
    if (tm === null) {
      return raw
    }
    let minutes: number = SemanticParser.strToNum(tm[1])
    if (tm[2] === '小时') {
      minutes = minutes * 60
    }
    const rate: number = factorId === 'T01' ? 0.33 : 0.08 // 骑行≈20km/h,步行≈5km/h
    return Math.max(0.1, Math.round(minutes * rate * 10) / 10)
  }
}
