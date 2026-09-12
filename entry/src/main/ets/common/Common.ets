import { promptAction } from '@kit.ArkUI'

/** 数据变更事件 id(记录增删后广播,页面刷新) */
export const EVT_DATA_CHANGED: number = 1001

/** 全局轻提示 */
export function toast(msg: string): void {
  promptAction.showToast({ message: msg, duration: 1500 })
}
