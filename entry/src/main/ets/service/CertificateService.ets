import { common } from '@kit.AbilityKit'
import { Database } from '../data/Database'

/** 电子植树证书 */
export interface TreeCert {
  /** 证书编号,如 ZL-2026-0001 */
  serial: string
  /** 持证人姓名 */
  name: string
  /** 颁发时累计碳减排(kgCO2e) */
  co2: number
  /** 颁发日期 YYYY-MM-DD */
  date: string
  /** 认植树种 */
  species: string
}

const KV_CERTS: string = 'tree_certs'
const KV_NAME: string = 'profile_name'

/** 认植树种池(按颁发顺序轮换,保证每张证书有独立的树种署名) */
const SPECIES_POOL: string[] = ['樟子松', '沙棘', '侧柏', '银杏', '国槐', '胡杨']

/**
 * 植树证书服务(全离线)
 * 证书列表与持证人姓名均落在本地 kv_store,不依赖云端。
 */
export class CertificateService {
  /** 读取默认持证人姓名 */
  static async profileName(ctx: common.UIAbilityContext): Promise<string> {
    return Database.kvGet(ctx, KV_NAME, '零屿岛民')
  }

  /** 保存默认持证人姓名 */
  static async setProfileName(ctx: common.UIAbilityContext, name: string): Promise<void> {
    await Database.kvSet(ctx, KV_NAME, name)
  }

  /** 按颁发时间先后列出全部证书(最早的在前) */
  static async list(ctx: common.UIAbilityContext): Promise<TreeCert[]> {
    const raw: string = await Database.kvGet(ctx, KV_CERTS, '[]')
    try {
      const arr = JSON.parse(raw) as TreeCert[]
      return Array.isArray(arr) ? arr : []
    } catch (e) {
      return []
    }
  }

  /** 颁发一张新证书(以当前累计减排与默认姓名为准) */
  static async issue(ctx: common.UIAbilityContext, co2: number): Promise<TreeCert> {
    const list: TreeCert[] = await CertificateService.list(ctx)
    const name: string = await CertificateService.profileName(ctx)
    const cert: TreeCert = {
      serial: CertificateService.makeSerial(list.length + 1),
      name: name,
      co2: co2,
      date: Database.today(),
      species: SPECIES_POOL[list.length % SPECIES_POOL.length]
    }
    list.push(cert)
    await Database.kvSet(ctx, KV_CERTS, JSON.stringify(list))
    return cert
  }

  /** 重命名指定证书的持证人 */
  static async rename(ctx: common.UIAbilityContext, serial: string, name: string): Promise<void> {
    const list: TreeCert[] = await CertificateService.list(ctx)
    for (const c of list) {
      if (c.serial === serial) {
        c.name = name
      }
    }
    await Database.kvSet(ctx, KV_CERTS, JSON.stringify(list))
  }

  /** 生成证书编号:ZL-年份-四位流水 */
  private static makeSerial(seq: number): string {
    const year: number = new Date().getFullYear()
    let s: string = `${seq}`
    while (s.length < 4) {
      s = `0${s}`
    }
    return `ZL-${year}-${s}`
  }
}
