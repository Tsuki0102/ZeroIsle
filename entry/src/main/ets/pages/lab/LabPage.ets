import { common } from '@kit.AbilityKit'
import { emitter } from '@kit.BasicServicesKit'
import { ZeroTheme } from '../../common/Theme'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { Database } from '../../data/Database'

/** 通勤方式的碳因子(与因子库口径一致) */
interface CommuteMode {
  key: string
  name: string
  icon: string
  factor: number
  factorId: string
}

const COMMUTE_MODES: CommuteMode[] = [
  { key: 'walk', name: '步行', icon: '🚶', factor: 0.20, factorId: 'T02' },
  { key: 'bike', name: '骑行', icon: '🚲', factor: 0.20, factorId: 'T01' },
  { key: 'bus', name: '公交', icon: '🚌', factor: 0.10, factorId: 'T03' },
  { key: 'metro', name: '地铁', icon: '🚇', factor: 0.13, factorId: 'T04' },
  { key: 'car', name: '驾车', icon: '🚗', factor: 0.00, factorId: 'T07' }
]

interface LabArticle {
  id: string
  title: string
  category: string
  minutes: number
  body: string
}

const ARTICLES: LabArticle[] = [
  {
    id: 'a1',
    title: '碳达峰与碳中和,有什么不同?',
    category: '双碳基础',
    minutes: 3,
    body: '碳达峰,是指二氧化碳排放总量达到历史最高值后进入下降通道——好比爬到山顶。我国承诺在 2030 年前实现碳达峰。\n碳中和,则是排放的二氧化碳与植树造林、碳捕集等吸收的量相互抵消,实现"净零排放"——好比下山后把脚印全部抹平。我国承诺 2060 年前实现碳中和。\n两个时间点,一个管"增量见顶",一个管"存量归零"。对我们每个人来说,双碳不是宏大叙事:你少开一次车、光盘一餐饭,都是在为国家承诺的兑现投票。'
  },
  {
    id: 'a2',
    title: '1 度电 = 多少碳?',
    category: '互动计算器',
    minutes: 2,
    body: '按全国电网平均排放因子,每消耗 1 度电约对应 0.57 kg CO₂e。\n这意味着:一台 1.5 匹空调调高 1℃ 运行 8 小时,约省电 0.9 度 ≈ 减排 0.5 kg;宿舍彻底关闭待机电器一晚,约省 0.09 度。\n别小看这些数字:全国高校宿舍如果每间每天省 1 度电,一年下来减少的碳排放相当于多种下数十万棵树。这就是"宿舍节电挑战"背后的真实分量。'
  },
  {
    id: 'a3',
    title: '为什么少吃一顿肉 ≈ 种半棵树?',
    category: '低碳生活',
    minutes: 3,
    body: '生产 1 kg 牛肉的碳足迹约 27 kg CO₂e,是同等重量蔬菜的数十倍。一份普通肉食餐的碳足迹约 1.5-2 kg,而素食餐仅 0.5 kg 左右——差值接近 1 kg CO₂e。\n一棵树一年大约固碳 10 kg。也就是说,每周 5 天选择素食晚餐,一年累积的减排量约等于种下半棵树。\n不是要求人人吃素,而是"有意识地选择":每周一顿素,就是给岛屿种下一片叶子。'
  },
  {
    id: 'a4',
    title: '快递纸箱的第二次生命',
    category: '资源循环',
    minutes: 2,
    body: '每回收 1 kg 废纸,可避免约 1.5 kg CO₂e 排放——再生纸比原生纸少消耗约 60% 的能源与水。\n一个标准快递箱约 0.3 kg,校园快递站每天拆掉的纸箱数以千计。把它们投进回收箱而不是垃圾桶,是大学生最容易做到的低碳行为之一。\n在零屿里记录"回收纸张",系统会按这个口径为你的岛屿积累生态值。'
  }
]

/** 碳知实验室「验」:知识 × 互动计算器,可一键记录 */
@Component
export struct LabPage {
  @State expandedId: string = ''
  @State calcMode: string = 'bike'
  @State calcKm: string = '5'
  @State meals: string = '5'
  @State kwh: string = '10'

  private mode(): CommuteMode {
    for (const m of COMMUTE_MODES) {
      if (m.key === this.calcMode) {
        return m
      }
    }
    return COMMUTE_MODES[1]
  }

  private km(): number {
    const v: number = parseFloat(this.calcKm)
    return isNaN(v) ? 0 : v
  }

  private commuteCo2(): number {
    const m = this.mode()
    if (m.key === 'car') {
      return this.km() * 0.20
    }
    return this.km() * m.factor
  }

  private saveCommute(): void {
    const m = this.mode()
    if (m.key === 'car' || this.km() <= 0) {
      toast('驾车不产生减排,选个绿色方式并输入距离吧')
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    Database.insertRecord(ctx, m.factorId, this.km(), '手动', '碳知实验室').then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      toast(`已记录 ${m.name}${this.km()} 公里,岛屿在生长!`)
    })
  }

  private saveMeals(): void {
    const n: number = parseFloat(this.meals)
    if (isNaN(n) || n <= 0) {
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    Database.insertRecord(ctx, 'F01', n, '手动', '碳知实验室').then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      toast(`已记录光盘 ${n} 餐!`)
    })
  }

  private saveKwh(): void {
    const n: number = parseFloat(this.kwh)
    if (isNaN(n) || n <= 0) {
      return
    }
    const ctx = getContext(this) as common.UIAbilityContext
    Database.insertRecord(ctx, 'E01', n, '手动', '碳知实验室').then(() => {
      emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
      toast(`已记录节电 ${n} 度!`)
    })
  }

  build() {
    Column() {
      // 标题
      Column() {
        Text('碳知实验室').fontSize(22).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
        Text('把复杂的知识,变成今天能做的小行动').fontSize(11).fontColor(ZeroTheme.textSub).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      Scroll() {
        Column() {
          // 实验室头图
          Image($rawfile('lab_header.jpg'))
            .width('100%')
            .height(140)
            .objectFit(ImageFit.Cover)
            .borderRadius(ZeroTheme.radiusM)
            .margin({ top: 12 })

          // ===== 计算器 1:通勤 =====
          Column() {
            Row({ space: 6 }) {
              Text('🧮').fontSize(16)
              Text('通勤碳计算器').fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
              Text('可一键记录').fontSize(9).fontColor(ZeroTheme.textLight)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(ZeroTheme.accent)
                .borderRadius(6)
            }

            Row({ space: 6 }) {
              ForEach(COMMUTE_MODES, (m: CommuteMode) => {
                Text(`${m.icon}\n${m.name}`)
                  .fontSize(11)
                  .fontColor(this.calcMode === m.key ? ZeroTheme.textLight : ZeroTheme.textMain)
                  .textAlign(TextAlign.Center)
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor(this.calcMode === m.key ? ZeroTheme.primary : ZeroTheme.bg)
                  .borderRadius(12)
                  .onClick(() => {
                    this.calcMode = m.key
                  })
              }, (m: CommuteMode) => m.key)
            }
            .width('100%')
            .margin({ top: 10 })

            Row({ space: 8 }) {
              Text('距离').fontSize(13).fontColor(ZeroTheme.textSub)
              TextInput({ text: this.calcKm })
                .type(InputType.NUMBER_DECIMAL)
                .fontSize(14).height(36).width(90)
                .textAlign(TextAlign.Center)
                .backgroundColor(ZeroTheme.bg)
                .onChange((v: string) => {
                  this.calcKm = v
                })
              Text('公里').fontSize(13).fontColor(ZeroTheme.textSub)
              Blank()
              if (this.mode().key !== 'car') {
                Text(`排放 ${(this.commuteCo2()).toFixed(2)} kg`)
                  .fontSize(13).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
              } else {
                Text(`比骑行多排 ${(this.commuteCo2() - this.km() * 0.2 >= 0 ? this.commuteCo2() - this.km() * 0.2 : 0).toFixed(2)} kg`)
                  .fontSize(13).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.danger)
              }
            }
            .width('100%')
            .margin({ top: 12 })

            Button(this.mode().key === 'car' ? '换种方式再来看' : '一键记录这次通勤')
              .fontSize(13)
              .width('100%')
              .height(38)
              .backgroundColor(this.mode().key === 'car' ? ZeroTheme.bg : ZeroTheme.primary)
              .fontColor(this.mode().key === 'car' ? ZeroTheme.textSub : ZeroTheme.textLight)
              .margin({ top: 10 })
              .onClick(() => {
                this.saveCommute()
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor(ZeroTheme.cardBg)
          .borderRadius(ZeroTheme.radiusM)

          // ===== 计算器 2:节电 =====
          Column() {
            Row({ space: 6 }) {
              Text('🧮').fontSize(16)
              Text('节电换算器').fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
            }
            Row({ space: 8 }) {
              Text('本周省电').fontSize(13).fontColor(ZeroTheme.textSub)
              TextInput({ text: this.kwh })
                .type(InputType.NUMBER_DECIMAL)
                .fontSize(14).height(36).width(80)
                .textAlign(TextAlign.Center)
                .backgroundColor(ZeroTheme.bg)
                .onChange((v: string) => {
                  this.kwh = v
                })
              Text('度 ≈').fontSize(13).fontColor(ZeroTheme.textSub)
              Text(`${((parseFloat(this.kwh) || 0) * 0.57).toFixed(2)} kg 减排`)
                .fontSize(13).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
              Blank()
              Button('记录')
                .fontSize(12).height(32).backgroundColor(ZeroTheme.primary)
                .onClick(() => {
                  this.saveKwh()
                })
            }
            .width('100%')
            .margin({ top: 10 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor(ZeroTheme.cardBg)
          .borderRadius(ZeroTheme.radiusM)
          .margin({ top: 12 })

          // ===== 计算器 3:光盘 =====
          Column() {
            Row({ space: 6 }) {
              Text('🧮').fontSize(16)
              Text('光盘打卡器').fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
            }
            Row({ space: 8 }) {
              Text('今天光盘').fontSize(13).fontColor(ZeroTheme.textSub)
              TextInput({ text: this.meals })
                .type(InputType.NUMBER_DECIMAL)
                .fontSize(14).height(36).width(70)
                .textAlign(TextAlign.Center)
                .backgroundColor(ZeroTheme.bg)
                .onChange((v: string) => {
                  this.meals = v
                })
              Text('餐 ≈').fontSize(13).fontColor(ZeroTheme.textSub)
              Text(`${((parseFloat(this.meals) || 0) * 0.25).toFixed(2)} kg 减排`)
                .fontSize(13).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.primary)
              Blank()
              Button('记录')
                .fontSize(12).height(32).backgroundColor(ZeroTheme.primary)
                .onClick(() => {
                  this.saveMeals()
                })
            }
            .width('100%')
            .margin({ top: 10 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor(ZeroTheme.cardBg)
          .borderRadius(ZeroTheme.radiusM)
          .margin({ top: 12 })

          // ===== 知识文章 =====
          Text('低碳知识库')
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ZeroTheme.textMain)
            .margin({ top: 6 })

          ForEach(ARTICLES, (a: LabArticle) => {
            Column() {
              Row() {
                Text(a.category)
                  .fontSize(9).fontColor(ZeroTheme.primary)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor(ZeroTheme.primaryLight)
                  .borderRadius(6)
                Blank()
                Text(`${a.minutes} 分钟`).fontSize(9).fontColor(ZeroTheme.textSub)
              }.width('100%')

              Text(a.title)
                .fontSize(15).fontWeight(FontWeight.Medium).fontColor(ZeroTheme.textMain)
                .margin({ top: 8 })

              if (this.expandedId === a.id) {
                Text(a.body)
                  .fontSize(13)
                  .fontColor(ZeroTheme.textMain)
                  .lineHeight(20)
                  .margin({ top: 8 })
                Text('收起 ↑')
                  .fontSize(11).fontColor(ZeroTheme.primary).margin({ top: 6 })
              } else {
                Text('展开阅读 ↓')
                  .fontSize(11).fontColor(ZeroTheme.primary).margin({ top: 6 })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(ZeroTheme.padM)
            .backgroundColor(ZeroTheme.cardBg)
            .borderRadius(ZeroTheme.radiusM)
            .margin({ top: 10 })
            .onClick(() => {
              this.expandedId = this.expandedId === a.id ? '' : a.id
            })
          }, (a: LabArticle) => a.id)

          Column().height(20)
        }
        .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 14 })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZeroTheme.bg)
  }
}
