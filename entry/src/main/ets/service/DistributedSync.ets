import { distributedKVStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'

/**
 * 超级终端分布式同步服务(创新拓展①真实落地)
 *
 * 基于分布式 KV 库(distributedKVStore)实现同华为账号多设备(手机/平板)间的
 * 碳账本自动同步与合并统计,对应赛题「超级终端多设备数据同步、家庭碳积分合并统计」。
 *
 * 设计要点:
 *  - 采用 DEVICE_COLLABORATION 设备协作库,每台设备写入自己的分区(key 统一为 `carbon_summary`),
 *    跨设备同步后通过 getEntries 汇总所有设备的减排量,天然避免同 key 覆盖冲突。
 *  - autoSync 开启后,登录同一华为账号的超级终端会在网络可达时自动汇聚;
 *    亦可手动 syncNow() 主动触发 PUSH_PULL。
 *  - 监听 SUBSCRIBE_TYPE_REMOTE 的 dataChange,远端数据变化时主动回调上层刷新。
 *  - 环境不支持(模拟器 / 未開启分布式能力 / 无同一账号设备)时优雅降级:
 *    init 返回 false,上层据此隐藏或提示,本地账本与家庭合并不受影响。
 */

export interface DeviceSummary {
  points: number
  co2: number
  updatedAt: number
}

export interface DistAggregate {
  deviceCount: number
  points: number
  co2: number
}

const STORE_ID: string = 'zeroisle_carbon_sync'
const SUMMARY_KEY: string = 'carbon_summary'

export class DistributedSync {
  private static store: distributedKVStore.DeviceKVStore | null = null
  private static inited: boolean = false
  private static available: boolean = false
  private static errorMsg: string = ''
  private static listener: (() => void) | null = null

  static isAvailable(): boolean {
    return DistributedSync.available
  }

  static getError(): string {
    return DistributedSync.errorMsg
  }

  /** 是否已尝试初始化(避免重复创建 KVManager) */
  static hasInit(): boolean {
    return DistributedSync.inited
  }

  /** 应用启动时调用一次:创建分布式 KV 库并开启自动同步与远端监听 */
  static async init(ctx: common.UIAbilityContext): Promise<boolean> {
    if (DistributedSync.inited) {
      return DistributedSync.available
    }
    DistributedSync.inited = true
    try {
      const config: distributedKVStore.KVManagerConfig = {
        bundleName: 'com.zeroisle.isle',
        context: ctx
      }
      const kvManager: distributedKVStore.KVManager = distributedKVStore.createKVManager(config)
      const options: distributedKVStore.Options = {
        createIfMissing: true,
        encrypt: true,
        backup: false,
        autoSync: true,
        kvStoreType: distributedKVStore.KVStoreType.DEVICE_COLLABORATION,
        securityLevel: distributedKVStore.SecurityLevel.S1
      }
      const store = await kvManager.getKVStore<distributedKVStore.DeviceKVStore>(STORE_ID, options)
      store.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_REMOTE, (_change: distributedKVStore.ChangeNotification) => {
        if (DistributedSync.listener !== null) {
          DistributedSync.listener()
        }
      })
      DistributedSync.store = store
      DistributedSync.available = true
      return true
    } catch (err) {
      DistributedSync.available = false
      const e = err as BusinessError
      DistributedSync.errorMsg = (e && e.message) ? e.message : '分布式能力不可用'
      return false
    }
  }

  /** 注册远端数据变化回调(上层用于刷新合并视图) */
  static onRemoteChange(cb: () => void): void {
    DistributedSync.listener = cb
  }

  /** 把本机汇总写入分布式库(覆盖本机分区) */
  static async pushLocal(points: number, co2: number): Promise<void> {
    if (!DistributedSync.store) {
      return
    }
    const payload: DeviceSummary = { points, co2, updatedAt: Date.now() }
    try {
      await DistributedSync.store.put(SUMMARY_KEY, JSON.stringify(payload))
    } catch (err) {
      // 写入失败不影响本地,忽略
    }
  }

  /** 主动触发一次跨设备同步(推 + 拉) */
  static syncNow(): void {
    if (!DistributedSync.store) {
      return
    }
    try {
      DistributedSync.store.sync([], distributedKVStore.SyncMode.PUSH_PULL)
    } catch (err) {
      // 无可信设备 / 无网络时同步会失败,属正常,忽略
    }
  }

  /** 汇总所有设备(含本机)的碳积分与减排量 */
  static async aggregate(): Promise<DistAggregate> {
    if (!DistributedSync.store) {
      return { deviceCount: 0, points: 0, co2: 0 }
    }
    try {
      const entries: Array<distributedKVStore.Entry> = await DistributedSync.store.getEntries(SUMMARY_KEY)
      let points: number = 0
      let co2: number = 0
      for (const entry of entries) {
        try {
          const raw = (entry.value as distributedKVStore.Value).value
          if (typeof raw !== 'string') {
            continue
          }
          const obj = JSON.parse(raw) as DeviceSummary
          points += obj.points ?? 0
          co2 += obj.co2 ?? 0
        } catch (err) {
          // 跳过损坏项
        }
      }
      return { deviceCount: entries.length, points, co2 }
    } catch (err) {
      return { deviceCount: 0, points: 0, co2: 0 }
    }
  }
}
