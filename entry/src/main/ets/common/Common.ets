import { promptAction } from '@kit.ArkUI'

/** 数据变更事件 id(记录增删后广播,页面刷新) */
export const EVT_DATA_CHANGED: number = 1001

/** 任务「去完成」跳转事件(切到「记」Tab) */
export const EVT_GO_RECORD: number = 1002

/** 桌面卡片点击跳转事件(切到「析」Tab) */
export const EVT_CARD_NAV: number = 1003

/** 桌面卡片冷启动跳转目标(EntryAbility 写入,Index 消费后清空) */
let cardNavTarget: string = ''

export function setCardNavTarget(target: string): void {
  cardNavTarget = target
}

export function takeCardNavTarget(): string {
  const t: string = cardNavTarget
  cardNavTarget = ''
  return t
}

/** 全局轻提示 */
export function toast(msg: string): void {
  promptAction.showToast({ message: msg, duration: 1500 })
}
