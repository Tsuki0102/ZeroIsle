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
      let amount: number = 1
      const m: RegExpMatchArray | null = clause.match(/(\d+(?:\.\d+)?)/)
      if (m !== null) {
        const v: number = parseFloat(m[1])
        if (!isNaN(v) && v > 0) {
          amount = v
        }
      }
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
}
