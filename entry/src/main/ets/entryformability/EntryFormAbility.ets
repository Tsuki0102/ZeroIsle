import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit'
import { Want } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'

interface CardData {
  today: string
  points: string
  streak: string
  stage: string
}

const EMPTY: CardData = { today: '0.00', points: '0', streak: '0', stage: '灰屿' }

const STAGES: string[] = ['灰屿', '青屿', '绿屿', '森屿', '生态屿']
const THRESHOLDS: number[] = [0, 10, 50, 150, 400]

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
            // 阶段
            let idx: number = 0
            for (let i = 0; i < THRESHOLDS.length; i++) {
              if (co2 >= THRESHOLDS[i]) {
                idx = i
              }
            }
            out.stage = STAGES[idx]
            // 今日减排(本地日期,与主应用口径一致)
            const d = new Date()
            const mm: string = (d.getMonth() + 1) < 10 ? '0' + (d.getMonth() + 1) : '' + (d.getMonth() + 1)
            const dd: string = d.getDate() < 10 ? '0' + d.getDate() : '' + d.getDate()
            const todayStr: string = `${d.getFullYear()}-${mm}-${dd}`
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
                // 打卡天数(distinct 日期数,简化口径)
                const pd = new relationalStore.RdbPredicates('behavior_record')
                pd.distinct()
                store.query(pd, ['record_date']).then((rs4: relationalStore.ResultSet) => {
                  let days: number = 0
                  while (rs4.goToNextRow()) {
                    days++
                  }
                  rs4.close()
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
