import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit'
import { Want } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { ISLAND_STAGES } from '../model/Models'

interface CardData {
  today: string
  points: string
  streak: string
  stage: string
}

const EMPTY: CardData = { today: '0.00', points: '0', streak: '0', stage: '灰屿' }

function fmtDay(d: Date): string {
  const mm: string = (d.getMonth() + 1) < 10 ? '0' + (d.getMonth() + 1) : '' + (d.getMonth() + 1)
  const dd: string = d.getDate() < 10 ? '0' + d.getDate() : '' + d.getDate()
  return `${d.getFullYear()}-${mm}-${dd}`
}

/**
 * 桌面服务卡片数据源:直接读取本机数据库,离线刷新
 */
export default class EntryFormAbility extends FormExtensionAbility {
  private queryStats(): Promise<CardData> {
    return new Promise<CardData>((resolve) => {
      const config: relationalStore.StoreConfig = {
        name: 'zeroisle.db',
        securityLevel: relationalStore.SecurityLevel.S1
      }
      relationalStore.getRdbStore(this.context, config).then((store: relationalStore.RdbStore) => {
        const out: CardData = { today: EMPTY.today, points: EMPTY.points, streak: EMPTY.streak, stage: EMPTY.stage }
        // 累计岛币(行为+奖励)与累计减排
        store.query(new relationalStore.RdbPredicates('behavior_record'),
          ['COUNT(*) AS cnt', 'SUM(co2_kg) AS co2', 'SUM(points) AS pts']).then((rs: relationalStore.ResultSet) => {
          if (rs.goToFirstRow()) {
            const co2: number = rs.getDouble(rs.getColumnIndex('co2'))
            let pts: number = rs.getDouble(rs.getColumnIndex('pts'))
            // 阶段(与主应用 ISLAND_STAGES 单一来源)
            let idx: number = 0
            for (let i = 0; i < ISLAND_STAGES.length; i++) {
              if (co2 >= ISLAND_STAGES[i].thresholdKg) {
                idx = i
              }
            }
            out.stage = ISLAND_STAGES[idx].name
            // 今日减排(本地日期,与主应用口径一致)
            const todayStr: string = fmtDay(new Date())
            const p = new relationalStore.RdbPredicates('behavior_record')
            p.equalTo('record_date', todayStr)
            store.query(p, ['SUM(co2_kg) AS today']).then((rs2: relationalStore.ResultSet) => {
              if (rs2.goToFirstRow()) {
                out.today = rs2.getDouble(rs2.getColumnIndex('today')).toFixed(2)
              }
              rs2.close()
              // 奖励岛币
              store.query(new relationalStore.RdbPredicates('reward_log'),
                ['SUM(points) AS rp']).then((rs3: relationalStore.ResultSet) => {
                if (rs3.goToFirstRow()) {
                  pts += rs3.getDouble(rs3.getColumnIndex('rp'))
                }
                rs3.close()
                // 连续打卡天数(与主应用 Database.streak 同口径:从今天或昨天往前连续有记录)
                const pd = new relationalStore.RdbPredicates('behavior_record')
                pd.distinct()
                store.query(pd, ['record_date']).then((rs4: relationalStore.ResultSet) => {
                  const set: Set<string> = new Set()
                  while (rs4.goToNextRow()) {
                    set.add(rs4.getString(rs4.getColumnIndex('record_date')))
                  }
                  rs4.close()
                  let days: number = 0
                  const cur = new Date()
                  if (!set.has(fmtDay(cur))) {
                    cur.setDate(cur.getDate() - 1)
                  }
                  while (set.has(fmtDay(cur))) {
                    days++
                    cur.setDate(cur.getDate() - 1)
                  }
                  out.points = `${Math.round(pts)}`
                  out.streak = `${days}`
                  resolve(out)
                }).catch(() => resolve(out))
              }).catch(() => resolve(out))
            }).catch(() => resolve(out))
          } else {
            rs.close()
            resolve(out)
          }
        }).catch(() => resolve(out))
      }).catch(() => resolve(EMPTY))
    })
  }

  private push(formId: string): void {
    this.queryStats().then((d: CardData) => {
      formProvider.updateForm(formId, formBindingData.createFormBindingData(d)).catch(() => {})
    })
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = (want.parameters?.['ohos.extra.param.key.form_identity'] ?? '') as string
    if (formId !== '') {
      this.push(formId)
    }
    return formBindingData.createFormBindingData(EMPTY)
  }

  onUpdateForm(formId: string): void {
    this.push(formId)
  }

  onFormUninstall(formId: string): void {
  }

  onRemoveForm(formId: string): void {
  }

  onFormEvent(formId: string, message: string): void {
  }
}
