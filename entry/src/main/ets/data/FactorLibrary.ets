import { BehaviorCategory, BehaviorFactor, Scene } from '../model/Models'

/**
 * 碳排放因子库(内置离线)
 * 口径:参考公开发布的省级温室气体清单、全国电网平均排放因子及主流碳普惠平台量级
 * 积分规则:1 kgCO2e = 10 岛币
 */
export class FactorLibrary {
  static readonly categories: BehaviorCategory[] = [
    { id: 'travel', name: '绿色出行', icon: '🚌' },
    { id: 'energy', name: '节水节电', icon: '⚡' },
    { id: 'food', name: '光盘餐饮', icon: '🍚' },
    { id: 'recycle', name: '旧物回收', icon: '♻️' },
    { id: 'habit', name: '绿色习惯', icon: '🌱' }
  ]

  static readonly factors: BehaviorFactor[] = [
    { id: 'T01', categoryId: 'travel', scene: '通勤', name: '骑行代替驾车', unit: '公里', factor: 0.20, tip: '按燃油车每公里约0.2kg CO2e计' },
    { id: 'T02', categoryId: 'travel', scene: '通勤', name: '步行代替驾车', unit: '公里', factor: 0.20, tip: '按燃油车每公里约0.2kg CO2e计' },
    { id: 'T03', categoryId: 'travel', scene: '通勤', name: '公交代替私家车', unit: '公里', factor: 0.10, tip: '公交人均排放约为私家车的1/3' },
    { id: 'T04', categoryId: 'travel', scene: '通勤', name: '地铁代替私家车', unit: '公里', factor: 0.13, tip: '地铁人均排放约为私家车的1/2' },
    { id: 'T05', categoryId: 'travel', scene: '通勤', name: '拼车代替独驾', unit: '公里', factor: 0.10, tip: '两人同行各减一半' },
    { id: 'T06', categoryId: 'travel', scene: '通勤', name: '新能源车代替燃油车', unit: '公里', factor: 0.06, tip: '按当前电网结构下的差额' },
    { id: 'T07', categoryId: 'travel', scene: '通勤', name: '少开一天车', unit: '次', factor: 2.00, tip: '按日均通勤10km估算' },
    { id: 'T08', categoryId: 'travel', scene: '通用', name: '步行上下楼代替电梯', unit: '次', factor: 0.03, tip: '电梯每次运行约0.03kg CO2e' },

    { id: 'E01', categoryId: 'energy', scene: '宿舍', name: '节约用电', unit: '度', factor: 0.57, tip: '全国电网平均排放因子参考值' },
    { id: 'E02', categoryId: 'energy', scene: '宿舍', name: '空调调高1℃', unit: '次', factor: 0.50, tip: '按运行8小时估算节电量' },
    { id: 'E03', categoryId: 'energy', scene: '宿舍', name: '关闭待机电器', unit: '晚', factor: 0.05, tip: '待机功耗约占家庭用电5%-10%' },
    { id: 'E04', categoryId: 'energy', scene: '宿舍', name: '淋浴代替泡澡', unit: '次', factor: 0.50, tip: '省水又省加热能耗' },
    { id: 'W01', categoryId: 'energy', scene: '宿舍', name: '节约用水', unit: '吨', factor: 0.30, tip: '按供水污水处理能耗折算' },
    { id: 'W02', categoryId: 'energy', scene: '宿舍', name: '一水多用', unit: '次', factor: 0.02, tip: '按每次节水约60升折算' },

    { id: 'F01', categoryId: 'food', scene: '食堂', name: '光盘行动', unit: '餐', factor: 0.25, tip: '每浪费1kg食物约2.5kg CO2e,光盘约省0.1kg' },
    { id: 'F02', categoryId: 'food', scene: '食堂', name: '素食一餐', unit: '餐', factor: 0.50, tip: '肉类餐饮碳足迹显著高于素食' },
    { id: 'F03', categoryId: 'food', scene: '宿舍', name: '少点一次外卖', unit: '次', factor: 0.35, tip: '含包装与配送环节' },
    { id: 'F04', categoryId: 'food', scene: '通用', name: '自带水杯', unit: '次', factor: 0.05, tip: '避免一次性纸杯/塑料杯' },
    { id: 'F05', categoryId: 'food', scene: '食堂', name: '自带餐具', unit: '次', factor: 0.05, tip: '避免一次性餐具' },

    { id: 'R01', categoryId: 'recycle', scene: '循环', name: '回收旧衣物', unit: '公斤', factor: 3.60, tip: '旧衣再生利用公开参考值' },
    { id: 'R02', categoryId: 'recycle', scene: '循环', name: '回收纸张', unit: '公斤', factor: 1.50, tip: '再生纸替代原生纸差额' },
    { id: 'R03', categoryId: 'recycle', scene: '循环', name: '回收塑料瓶', unit: '个', factor: 0.05, tip: 'PET再生替代原生料差额' },
    { id: 'R04', categoryId: 'recycle', scene: '循环', name: '回收金属', unit: '公斤', factor: 5.00, tip: '金属再生节能显著' },
    { id: 'R05', categoryId: 'recycle', scene: '循环', name: '旧物捐赠/二手转卖', unit: '件', factor: 1.00, tip: '延长物品寿命避免新购' },
    { id: 'R06', categoryId: 'recycle', scene: '循环', name: '回收小家电', unit: '件', factor: 2.00, tip: '含金属塑料再生价值' },

    { id: 'H01', categoryId: 'habit', scene: '通用', name: '自带购物袋', unit: '次', factor: 0.03, tip: '避免一次性塑料袋' },
    { id: 'H02', categoryId: 'habit', scene: '宿舍', name: '垃圾分类投放', unit: '次', factor: 0.05, tip: '提高资源化比例' },
    { id: 'H03', categoryId: 'habit', scene: '通用', name: '双面打印/无纸化', unit: '次', factor: 0.02, tip: '按节约纸张折算' },
    { id: 'H04', categoryId: 'habit', scene: '通用', name: '拒绝过度包装商品', unit: '次', factor: 0.10, tip: '按省去包装材料折算' },
    { id: 'H05', categoryId: 'habit', scene: '通用', name: '植树/认养绿植', unit: '棵', factor: 10.00, tip: '按一棵树年固碳量约10kg计' }
  ]

  static byCategory(categoryId: string): BehaviorFactor[] {
    return FactorLibrary.factors.filter((f: BehaviorFactor) => f.categoryId === categoryId)
  }

  static byId(factorId: string): BehaviorFactor {
    const found: BehaviorFactor[] =
      FactorLibrary.factors.filter((f: BehaviorFactor) => f.id === factorId)
    if (found.length > 0) {
      return found[0]
    }
    return FactorLibrary.factors[0]
  }

  static nameOf(factorId: string): string {
    return FactorLibrary.byId(factorId).name
  }

  static categoryOf(factorId: string): string {
    return FactorLibrary.byId(factorId).categoryId
  }

  static categoryName(categoryId: string): string {
    const found: BehaviorCategory[] =
      FactorLibrary.categories.filter((c: BehaviorCategory) => c.id === categoryId)
    return found.length > 0 ? found[0].name : categoryId
  }

  static categoryIcon(categoryId: string): string {
    const found: BehaviorCategory[] =
      FactorLibrary.categories.filter((c: BehaviorCategory) => c.id === categoryId)
    return found.length > 0 ? found[0].icon : '🌿'
  }

  static sceneLabel(scene: Scene | string): string {
    return scene as string
  }
}
