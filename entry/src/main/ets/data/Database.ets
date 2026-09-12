import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { POINTS_PER_KG } from '../model/Models'
import { FactorLibrary } from './FactorLibrary'
import { BehaviorFactor } from '../model/Models'

/** 汇总统计 */
export class Summary {
  count: number = 0
  totalCo2: number = 0
  totalPoints: number = 0
  todayCo2: number = 0
  todayCount: number = 0
}

/** 单日聚合(图表用) */
export class DailyPoint {
  date: string = ''
  co2: number = 0
  points: number = 0
}

/** 分类聚合 */
export class CategorySum {
  categoryId: string = ''
  co2: number = 0
  cnt: number = 0
}

/** 历史记录条目 */
export class HistoryItem {
  id: number = 0
  factorId: string = ''
  name: string = ''
  icon: string = ''
  amount: number = 0
  unit: string = ''
  co2Kg: number = 0
  points: number = 0
  date: string = ''
  source: string = ''
}

/**
 * 零屿本地数据层(RelationalStore / SQLite,全离线)
 */
export class Database {
  private static rdb: relationalStore.RdbStore | null = null

  private static readonly CREATE_RECORD: string = `CREATE TABLE IF NOT EXISTS behavior_record (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    factor_id TEXT NOT NULL,
    category_id TEXT NOT NULL,
    scene TEXT NOT NULL,
    amount REAL NOT NULL,
    unit TEXT NOT NULL,
    co2_kg REAL NOT NULL,
    points INTEGER NOT NULL,
    record_date TEXT NOT NULL,
    note TEXT DEFAULT '',
    source TEXT NOT NULL DEFAULT '手动',
    created_at INTEGER NOT NULL)`
  private static readonly CREATE_TASK_LOG: string = `CREATE TABLE IF NOT EXISTS task_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    finish_date TEXT NOT NULL,
    created_at INTEGER NOT NULL)`
  private static readonly CREATE_BADGE: string = `CREATE TABLE IF NOT EXISTS badge (
    badge_id TEXT PRIMARY KEY,
    unlocked_at INTEGER NOT NULL)`
  private static readonly CREATE_EXCHANGE: string = `CREATE TABLE IF NOT EXISTS exchange_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item TEXT NOT NULL,
    cost INTEGER NOT NULL,
    created_at INTEGER NOT NULL)`
  private static readonly CREATE_DEX: string = `CREATE TABLE IF NOT EXISTS dex_entry (
    species TEXT PRIMARY KEY,
    unlocked_at INTEGER NOT NULL)`
  private static readonly CREATE_KV: string = `CREATE TABLE IF NOT EXISTS kv_store (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL)`
  private static readonly CREATE_REWARD: string = `CREATE TABLE IF NOT EXISTS reward_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    period_key TEXT NOT NULL,
    points INTEGER NOT NULL,
    created_at INTEGER NOT NULL)`

  /** 获取(懒初始化)数据库 */
  static async get(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    if (Database.rdb !== null) {
      return Database.rdb
    }
    const config: relationalStore.StoreConfig = {
      name: 'zeroisle.db',
      securityLevel: relationalStore.SecurityLevel.S1
    }
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config)
    await store.executeSql(Database.CREATE_RECORD)
    await store.executeSql(Database.CREATE_TASK_LOG)
    await store.executeSql(Database.CREATE_BADGE)
    await store.executeSql(Database.CREATE_EXCHANGE)
    await store.executeSql(Database.CREATE_DEX)
    await store.executeSql(Database.CREATE_REWARD)
    await store.executeSql(Database.CREATE_KV)
    Database.rdb = store
    return store
  }

  // ---------- 日期工具 ----------

  static fmtDate(d: Date): string {
    const m: string = (d.getMonth() + 1) < 10 ? '0' + (d.getMonth() + 1) : '' + (d.getMonth() + 1)
    const day: string = d.getDate() < 10 ? '0' + d.getDate() : '' + d.getDate()
    return `${d.getFullYear()}-${m}-${day}`
  }

  static today(): string {
    return Database.fmtDate(new Date())
  }

  static dateBefore(daysAgo: number): string {
    const d = new Date()
    d.setDate(d.getDate() - daysAgo)
    return Database.fmtDate(d)
  }

  // ---------- 写入 ----------

  /** 插入一条行为记录,返回新行 id(按当天日期) */
  static async insertRecord(context: common.UIAbilityContext, factorId: string,
    amount: number, source: string, note: string): Promise<number> {
    return Database.insertRow(context, factorId, amount, Database.today(), source, note)
  }

  /** 插入指定日期的记录(演示数据/补录用) */
  static async insertRow(context: common.UIAbilityContext, factorId: string,
    amount: number, dateStr: string, source: string, note: string): Promise<number> {
    const store = await Database.get(context)
    const f: BehaviorFactor = FactorLibrary.byId(factorId)
    const co2: number = amount * f.factor
    const points: number = Math.round(co2 * POINTS_PER_KG)
    const bucket: relationalStore.ValuesBucket = {
      'factor_id': f.id,
      'category_id': f.categoryId,
      'scene': f.scene,
      'amount': amount,
      'unit': f.unit,
      'co2_kg': co2,
      'points': points,
      'record_date': dateStr,
      'note': note,
      'source': source,
      'created_at': Date.now()
    }
    return store.insert('behavior_record', bucket)
  }

  static async deleteRecord(context: common.UIAbilityContext, id: number): Promise<void> {
    const store = await Database.get(context)
    const p = new relationalStore.RdbPredicates('behavior_record')
    p.equalTo('id', id)
    await store.delete(p)
  }

  static async clearAll(context: common.UIAbilityContext): Promise<void> {
    const store = await Database.get(context)
    await store.delete(new relationalStore.RdbPredicates('behavior_record'))
  }

  // ---------- 聚合查询 ----------

  static async summary(context: common.UIAbilityContext): Promise<Summary> {
    const store = await Database.get(context)
    const s = new Summary()

    let rs: relationalStore.ResultSet = await store.query(
      new relationalStore.RdbPredicates('behavior_record'),
      ['COUNT(*) AS cnt', 'SUM(co2_kg) AS co2', 'SUM(points) AS pts'])
    if (rs.goToFirstRow()) {
      console.info(`[ZeroIsleDB] rowCols cnt=${rs.getColumnIndex('cnt')} co2=${rs.getColumnIndex('co2')} pts=${rs.getColumnIndex('pts')}`)
      s.count = rs.getDouble(rs.getColumnIndex('cnt'))
      s.totalCo2 = rs.getDouble(rs.getColumnIndex('co2'))
      s.totalPoints = rs.getDouble(rs.getColumnIndex('pts'))
      console.info(`[ZeroIsleDB] total cnt=${s.count} co2=${s.totalCo2} pts=${s.totalPoints}`)
    } else {
      console.info('[ZeroIsleDB] total query: NO ROW')
    }
    rs.close()

    // 叠加任务奖励岛币
    s.totalPoints += await Database.rewardSum(context)

    const p = new relationalStore.RdbPredicates('behavior_record')
    p.equalTo('record_date', Database.today())
    rs = await store.query(p, ['COUNT(*) AS cnt', 'SUM(co2_kg) AS co2'])
    if (rs.goToFirstRow()) {
      s.todayCount = rs.getDouble(rs.getColumnIndex('cnt'))
      s.todayCo2 = rs.getDouble(rs.getColumnIndex('co2'))
      console.info(`[ZeroIsleDB] today=${Database.today()} cnt=${s.todayCount} co2=${s.todayCo2}`)
    } else {
      console.info('[ZeroIsleDB] today query: NO ROW')
    }
    rs.close()
    return s
  }

  /** 最近 N 天逐日聚合(缺失日期由调用方补零) */
  static async dailySeries(context: common.UIAbilityContext, days: number): Promise<DailyPoint[]> {
    const store = await Database.get(context)
    const p = new relationalStore.RdbPredicates('behavior_record')
    p.greaterThanOrEqualTo('record_date', Database.dateBefore(days - 1))
    p.groupBy(['record_date'])
    p.orderByAsc('record_date')
    const rs: relationalStore.ResultSet = await store.query(p,
      ['record_date', 'SUM(co2_kg) AS co2', 'SUM(points) AS pts'])
    const list: DailyPoint[] = []
    while (rs.goToNextRow()) {
      const dp = new DailyPoint()
      dp.date = rs.getString(rs.getColumnIndex('record_date'))
      dp.co2 = rs.getDouble(rs.getColumnIndex('co2'))
      dp.points = rs.getLong(rs.getColumnIndex('pts'))
      list.push(dp)
    }
    rs.close()
    return list
  }

  static async categoryStats(context: common.UIAbilityContext): Promise<CategorySum[]> {
    const store = await Database.get(context)
    const p = new relationalStore.RdbPredicates('behavior_record')
    p.groupBy(['category_id'])
    const rs: relationalStore.ResultSet = await store.query(p,
      ['category_id', 'SUM(co2_kg) AS co2', 'COUNT(*) AS cnt'])
    const list: CategorySum[] = []
    while (rs.goToNextRow()) {
      const c = new CategorySum()
      c.categoryId = rs.getString(rs.getColumnIndex('category_id'))
      c.co2 = rs.getDouble(rs.getColumnIndex('co2'))
      c.cnt = rs.getLong(rs.getColumnIndex('cnt'))
      list.push(c)
    }
    rs.close()
    return list
  }

  static async history(context: common.UIAbilityContext, limit: number): Promise<HistoryItem[]> {
    const store = await Database.get(context)
    const p = new relationalStore.RdbPredicates('behavior_record')
    p.limitAs(limit)
    p.orderByDesc('created_at')
    const rs: relationalStore.ResultSet = await store.query(p, [
      'id', 'factor_id', 'amount', 'unit', 'co2_kg', 'points', 'record_date', 'source'])
    const list: HistoryItem[] = []
    while (rs.goToNextRow()) {
      const h = new HistoryItem()
      h.id = rs.getLong(rs.getColumnIndex('id'))
      h.factorId = rs.getString(rs.getColumnIndex('factor_id'))
      h.amount = rs.getDouble(rs.getColumnIndex('amount'))
      h.unit = rs.getString(rs.getColumnIndex('unit'))
      h.co2Kg = rs.getDouble(rs.getColumnIndex('co2_kg'))
      h.points = rs.getLong(rs.getColumnIndex('points'))
      h.date = rs.getString(rs.getColumnIndex('record_date'))
      h.source = rs.getString(rs.getColumnIndex('source'))
      h.name = FactorLibrary.nameOf(h.factorId)
      h.icon = FactorLibrary.categoryIcon(FactorLibrary.categoryOf(h.factorId))
      list.push(h)
    }
    rs.close()
    return list
  }

  /** 连续打卡天数:从今天(或昨天)往前数有记录的连续天数 */
  static async streak(context: common.UIAbilityContext): Promise<number> {
    const store = await Database.get(context)
    const p = new relationalStore.RdbPredicates('behavior_record')
    p.distinct()
    p.orderByDesc('record_date')
    const rs: relationalStore.ResultSet = await store.query(p, ['record_date'])
    const set: Set<string> = new Set()
    while (rs.goToNextRow()) {
      set.add(rs.getString(rs.getColumnIndex('record_date')))
    }
    rs.close()
    if (set.size === 0) {
      return 0
    }
    let cursor = new Date()
    if (!set.has(Database.fmtDate(cursor))) {
      cursor.setDate(cursor.getDate() - 1)
      if (!set.has(Database.fmtDate(cursor))) {
        return 0
      }
    }
    let n: number = 0
    while (set.has(Database.fmtDate(cursor))) {
      n++
      cursor.setDate(cursor.getDate() - 1)
    }
    console.info(`[ZeroIsleDB] streak set=${set.size} result=${n} appToday=${Database.today()}`)
    return n
  }

  // ---------- 通用 KV 存储(周榜舍友数据等)----------

  static async kvSet(context: common.UIAbilityContext, key: string, value: string): Promise<void> {
    const store = await Database.get(context)
    await store.executeSql('INSERT OR REPLACE INTO kv_store (key, value) VALUES (?, ?)', [key, value])
  }

  static async kvGet(context: common.UIAbilityContext, key: string, fallback: string): Promise<string> {
    const store = await Database.get(context)
    const p = new relationalStore.RdbPredicates('kv_store')
    p.equalTo('key', key)
    const rs: relationalStore.ResultSet = await store.query(p, ['value'])
    let v: string = fallback
    if (rs.goToFirstRow()) {
      v = rs.getString(rs.getColumnIndex('value'))
    }
    rs.close()
    return v
  }

  // ---------- 激励系统:任务奖励 / 兑换 ----------

  /** 任务奖励岛币累计 */
  static async rewardSum(context: common.UIAbilityContext): Promise<number> {
    const store = await Database.get(context)
    const rs: relationalStore.ResultSet = await store.query(
      new relationalStore.RdbPredicates('reward_log'), ['SUM(points) AS pts'])
    let v: number = 0
    if (rs.goToFirstRow()) {
      v = rs.getDouble(rs.getColumnIndex('pts'))
    }
    rs.close()
    return v
  }

  /** 兑换消耗岛币累计 */
  static async spentSum(context: common.UIAbilityContext): Promise<number> {
    const store = await Database.get(context)
    const rs: relationalStore.ResultSet = await store.query(
      new relationalStore.RdbPredicates('exchange_log'), ['SUM(cost) AS cost'])
    let v: number = 0
    if (rs.goToFirstRow()) {
      v = rs.getDouble(rs.getColumnIndex('cost'))
    }
    rs.close()
    return v
  }

  /**
   * 任务进度判定
   * check 格式:类型:参数:目标
   * today_count:F01 → 今日某行为条数;today_sum:T01 → 今日某行为数量和
   * week_count:travel → 本周(近7天)某分类条数;week_sum:energy → 本周某分类数量和
   */
  static async taskProgress(context: common.UIAbilityContext, check: string): Promise<number> {
    const store = await Database.get(context)
    const parts: string[] = check.split(':')
    const type: string = parts[0]
    const arg: string = parts.length > 1 ? parts[1] : ''
    const p = new relationalStore.RdbPredicates('behavior_record')
    let cols: string[] = ['COUNT(*) AS v']
    if (type === 'today_count') {
      p.equalTo('record_date', Database.today())
      p.equalTo('factor_id', arg)
    } else if (type === 'today_sum') {
      p.equalTo('record_date', Database.today())
      p.equalTo('factor_id', arg)
      cols = ['SUM(amount) AS v']
    } else if (type === 'week_count') {
      p.greaterThanOrEqualTo('record_date', Database.dateBefore(6))
      p.equalTo('category_id', arg)
    } else if (type === 'week_sum') {
      p.greaterThanOrEqualTo('record_date', Database.dateBefore(6))
      p.equalTo('category_id', arg)
      cols = ['SUM(amount) AS v']
    } else {
      return 0
    }
    const rs: relationalStore.ResultSet = await store.query(p, cols)
    let v: number = 0
    if (rs.goToFirstRow()) {
      v = rs.getDouble(rs.getColumnIndex('v'))
    }
    rs.close()
    return v
  }

  /** 该任务在该周期是否已领取 */
  static async hasClaimed(context: common.UIAbilityContext, taskId: string, periodKey: string): Promise<boolean> {
    const store = await Database.get(context)
    const p = new relationalStore.RdbPredicates('reward_log')
    p.equalTo('task_id', taskId)
    p.equalTo('period_key', periodKey)
    const rs: relationalStore.ResultSet = await store.query(p, ['id'])
    const found: boolean = rs.goToFirstRow()
    rs.close()
    return found
  }

  /** 领取任务奖励 */
  static async claimReward(context: common.UIAbilityContext, taskId: string,
    points: number, periodKey: string): Promise<void> {
    const store = await Database.get(context)
    const bucket: relationalStore.ValuesBucket = {
      'task_id': taskId,
      'period_key': periodKey,
      'points': points,
      'created_at': Date.now()
    }
    await store.insert('reward_log', bucket)
  }

  /** 岛币兑换(记消耗流水) */
  static async exchange(context: common.UIAbilityContext, itemName: string, cost: number): Promise<void> {
    const store = await Database.get(context)
    const bucket: relationalStore.ValuesBucket = {
      'item': itemName,
      'cost': cost,
      'created_at': Date.now()
    }
    await store.insert('exchange_log', bucket)
  }
}
