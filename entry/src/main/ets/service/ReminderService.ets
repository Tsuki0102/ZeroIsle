import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { BusinessError } from '@kit.BasicServicesKit'

/**
 * 每日低碳提醒:系统级定时提醒(闹钟型),由系统提醒代理调度,重启后仍生效
 * 模拟器/真机需通知权限;module.json5 已声明 ohos.permission.PUBLISH_AGENT_REMINDER
 */
export class ReminderService {
  private static readonly HOUR: number = 19
  private static readonly MINUTE: number = 30

  /** 开启每日提醒(幂等:先清理旧提醒再发布,重复点击不叠加) */
  static async enableDaily(): Promise<string> {
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
      if (be.code === 1700002) {
        return '请先在系统设置中允许「零屿」发送通知,再开启每日提醒'
      }
      return `提醒设置失败(code ${be.code ?? '?'}),请检查通知权限`
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
