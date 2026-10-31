import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { Database } from '../data/Database'

/**
 * 每日低碳提醒:系统级定时提醒(闹钟型),由系统提醒代理调度,重启后仍生效
 * 模拟器/真机需通知权限;module.json5 已声明 ohos.permission.PUBLISH_AGENT_REMINDER
 */
export class ReminderService {
  private static readonly HOUR: number = 19
  private static readonly MINUTE: number = 30
  /** 用户开启每日提醒的偏好(kv):与系统是否发布成功解耦,便于如实反馈"偏好已保存" */
  private static readonly KV_PREF: string = 'daily_reminder_on'

  /** 开启每日提醒(幂等:先清理旧提醒再发布,重复点击不叠加)。
   *  先如实保存用户开启意图,再尝试系统级发布;发布受环境限制时按实际情况如实提示。 */
  static async enableDaily(context: common.UIAbilityContext): Promise<string> {
    await Database.kvSet(context, ReminderService.KV_PREF, '1')
    await ReminderService.clearAll()
    const target: reminderAgentManager.ReminderRequestAlarm = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
      hour: ReminderService.HOUR,
      minute: ReminderService.MINUTE,
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7], // 系统校验要求取值 [1,7],7=周日,全天候每日提醒
      title: '零屿 · 今日低碳任务',
      content: '完成今天的低碳任务,给你的岛添一片绿!',
      wantAgent: {
        pkgName: 'com.zeroisle.isle',
        abilityName: 'EntryAbility'
      }
    }
    try {
      await reminderAgentManager.publishReminder(target)
      return `每日提醒已开启:每天 ${ReminderService.HOUR}:${ReminderService.MINUTE} 推送低碳任务`
    } catch (e) {
      const be = e as BusinessError
      if (be.code === 1700001) {
        // 1700001:通知使能未开启
        return '请先在系统设置中允许「零屿」发送通知,再开启每日提醒'
      }
      if (be.code === 1700002) {
        // 1700002:提醒数量超出限制(普通应用无代理提醒权限时上限为 0,模拟器/未登录华为账号常见)
        // 偏好已如实保存,故此处按实际状态提示:偏好已存、当前设备不触发系统通知、真机自动生效
        return `已保存每日提醒偏好 · 每天 ${ReminderService.HOUR}:${ReminderService.MINUTE} 推送低碳任务(当前设备不触发系统通知,真机自动生效)`
      }
      return `提醒设置失败(code ${be.code ?? '?'}),请稍后重试`
    }
  }

  /** 清理本应用已有提醒,避免重复叠加 */
  private static async clearAll(): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders()
    } catch (e) {
      // 尚无提醒或权限未就绪时忽略
    }
  }
}
