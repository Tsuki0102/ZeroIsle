import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { router, window } from '@kit.ArkUI'
import { emitter } from '@kit.BasicServicesKit'
import { notificationManager } from '@kit.NotificationKit'
import { preferences } from '@kit.ArkData'
import { ZeroTheme } from '../../common/Theme'
import { ZeroMotion } from '../../common/Motion'
import { toast, EVT_DATA_CHANGED } from '../../common/Common'
import { Database } from '../../data/Database'
import { ReminderService } from '../../service/ReminderService'

interface SettingRow {
  icon: string
  tint: string
  title: string
  desc: string
  kind: string
}

interface ModeOpt {
  key: string
  label: string
}

/** 设置页:外观(深色模式) / 关于 / 每日提醒 / 数据清空 */
@Entry
@Component
struct SettingsPage {
  @State mode: string = 'system'
  @State llmOn: boolean = false
  @State llmKey: string = ''
  @State nickname: string = ''
  private rows: SettingRow[] = [
    { icon: 'ic_leaf', tint: '#059669', title: '版本与关于', desc: '零屿 v1.0 · 关于这款应用', kind: 'about' },
    { icon: 'ic_bell', tint: '#D97706', title: '每日低碳提醒', desc: '每天 19:30 定时推送低碳任务,养成打卡习惯', kind: 'notify' },
    { icon: 'ic_recycle', tint: '#D96C5F', title: '清空全部数据', desc: '删除行为记录与岛屿进度,保留应用设置', kind: 'clear' }
  ]
  private modes: ModeOpt[] = [
    { key: 'system', label: '跟随系统' },
    { key: 'light', label: '浅色' },
    { key: 'dark', label: '深色' }
  ]

  aboutToAppear(): void {
    try {
      const pref = preferences.getPreferencesSync(getContext(this), { name: 'zeroisle_settings' })
      this.mode = pref.getSync('colorMode', 'system') as string
    } catch (err) {
      this.mode = 'system'
    }
    Database.kvGet(getContext(this) as common.UIAbilityContext, 'agent_llm_on', '').then((v: string) => {
      this.llmOn = v === '1'
    })
    Database.kvGet(getContext(this) as common.UIAbilityContext, 'agent_llm_key', '').then((v: string) => {
      this.llmKey = v
    })
    Database.getNickname(getContext(this) as common.UIAbilityContext).then((n: string) => {
      this.nickname = n
    })
  }

  /** 保存昵称(失焦/回车触发;仅在变化时写库) */
  private saveNickname(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    const v: string = this.nickname.trim()
    if (v === '') {
      return
    }
    Database.getNickname(ctx).then((old: string) => {
      if (old !== v) {
        Database.kvSet(ctx, 'my_nickname', v).then(() => {
          this.nickname = v
          toast('昵称已保存,导出数据包将以此署名')
        })
      }
    })
  }

  /** 保存 LLM Key(失焦/回车触发,替代逐字符写库) */
  private saveLlmKey(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    const v: string = this.llmKey.trim()
    Database.kvGet(ctx, 'agent_llm_key', '').then((old: string) => {
      if (old !== v) {
        Database.kvSet(ctx, 'agent_llm_key', v)
      }
    })
  }

  /** 外观三态(D1):立即生效 + 持久化 + 状态栏联动 */
  private applyMode(m: string): void {
    this.mode = m
    AppStorage.setOrCreate('darkOn', m === 'dark')
    const ctx = getContext(this) as common.UIAbilityContext
    const app = ctx.getApplicationContext()
    if (m === 'dark') {
      app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
    } else if (m === 'light') {
      app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
    } else {
      app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    }
    try {
      const pref = preferences.getPreferencesSync(ctx, { name: 'zeroisle_settings' })
      pref.putSync('colorMode', m)
      pref.flush()
    } catch (err) {
      // 持久化失败不影响本次会话
    }
    window.getLastWindow(ctx).then((w: window.Window) => {
      // 窗口底色随主题联动:深色下避免状态栏/导航区露出浅色底
      w.setWindowBackgroundColor(m === 'dark' ? '#0C1512' : '#F4F8F6')
      w.setWindowSystemBarProperties({ statusBarColor: 'rgba(0,0,0,0)', statusBarContentColor: m === 'dark' ? '#E8F1EC' : '#0F172A' })
    }).catch(() => {
    })
  }

  private onRow(kind: string): void {
    const ctx = getContext(this) as common.UIAbilityContext
    if (kind === 'about') {
      AlertDialog.show({
        title: '零屿 Zero Isle',
        message: 'v1.0 · 每一次低碳选择,都在给你的岛种下一片绿\n\n全部数据仅存储在本机,离线可用;备份与导出支持 JSON / CSV 两种格式。',
        autoCancel: true
      })
    } else if (kind === 'notify') {
      notificationManager.requestEnableNotification(ctx).then(async () => {
        const msg: string = await ReminderService.enableDaily()
        toast(msg)
      }).catch(() => {
        toast('通知权限未开启,可在系统设置中打开')
      })
    } else if (kind === 'clear') {
      AlertDialog.show({
        title: '确认清空?',
        message: '将删除全部行为记录、任务与兑换进度、证书与平台账务;保留外观、昵称、LLM Key 与收藏等设置。此操作不可恢复。',
        autoCancel: true,
        primaryButton: {
          value: '取消',
          action: () => {
          }
        },
        secondaryButton: {
          value: '确认清空',
          fontColor: '#D96C5F',
          action: () => {
            Database.clearAll(ctx).then(() => {
              emitter.emit({ eventId: EVT_DATA_CHANGED }, {})
              toast('已清空全部记录')
            })
          }
        }
      })
    }
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor($r('app.color.text_main'))
          .onClick(() => {
            router.back()
          })
        Blank()
        Text($r('app.string.title_settings')).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
        Blank()
        Row().width(22)
      }
      .width('100%')
      .padding({ left: ZeroTheme.padL, right: ZeroTheme.padL, top: 12 })

      List({ space: 8 }) {
        ListItem() {
          // 外观三态(D1)
          Column() {
            Row() {
              Text('外观').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
              Blank()
              Text('墨绿松石夜 · 品牌定制深色')
                .fontSize(10).fontColor($r('app.color.text_sub'))
            }
            .width('100%')

            Row({ space: 8 }) {
              ForEach(this.modes, (m: ModeOpt) => {
                Text(m.label)
                  .fontSize(13)
                  .fontColor(this.mode === m.key ? $r('app.color.text_light') : $r('app.color.text_main'))
                  .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                  .backgroundColor(this.mode === m.key ? $r('app.color.primary') : $r('app.color.bg'))
                  .borderRadius(16)
                  .onClick(() => {
                    this.applyMode(m.key)
                  })
              }, (m: ModeOpt) => m.key)
            }
            .margin({ top: 12 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.card'))
          .borderRadius(ZeroTheme.radiusM)
          .shadow({ radius: 10, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 3 })
        }

        ListItem() {
          // 我的昵称:家庭积分包/周榜数据包的导出署名
          Column({ space: 10 }) {
            Row({ space: 8 }) {
              Column() {
                Text('🙋').fontSize(16)
              }
              .justifyContent(FlexAlign.Center)
              .width(38)
              .height(38)
              .borderRadius(12)
              .backgroundColor('rgba(46,125,91,0.12)')

              Column() {
                Text('我的昵称').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                Text('家庭积分包与宿舍周榜的导出署名').fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 12 })
            }
            .width('100%')

            TextInput({ text: this.nickname, placeholder: '给自己起个名字,如:小明' })
              .fontSize(12)
              .height(38)
              .borderRadius(10)
              .backgroundColor($r('app.color.bg'))
              .border({ width: 1, color: $r('app.color.hairline') })
              .fontColor($r('app.color.text_main'))
              .placeholderColor($r('app.color.text_sub'))
              .onChange((v: string) => {
                this.nickname = v
              })
              .onSubmit(() => {
                this.saveNickname()
              })
              .onBlur(() => {
                this.saveNickname()
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.card'))
          .borderRadius(ZeroTheme.radiusM)
          .shadow({ radius: 10, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 3 })
        }

        ListItem() {
          // 岛灵智能增强(LLM):DeepSeek 兼容接口,失败自动降级本地规则
          Column({ space: 10 }) {
            Row({ space: 8 }) {
              Column() {
                Text('🤖').fontSize(16)
              }
              .justifyContent(FlexAlign.Center)
              .width(38)
              .height(38)
              .borderRadius(12)
              .backgroundColor('rgba(14,94,111,0.12)')

              Column() {
                Text('智能增强 (LLM)').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                Text('DeepSeek 兼容 · 失败自动降级本地规则').fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 12 })

              Toggle({ type: ToggleType.Switch, isOn: this.llmOn })
                .onChange((isOn: boolean) => {
                  this.llmOn = isOn
                  const ctx = getContext(this) as common.UIAbilityContext
                  Database.kvSet(ctx, 'agent_llm_on', isOn ? '1' : '0')
                  toast(isOn ? '智能增强已开启:岛灵将优先用大模型理解意图' : '智能增强已关闭:使用本地规则引擎')
                })
            }
            .width('100%')

            TextInput({ text: this.llmKey, placeholder: '粘贴 API Key(sk-…)' })
              .fontSize(12)
              .height(38)
              .borderRadius(10)
              .backgroundColor($r('app.color.bg'))
              .border({ width: 1, color: $r('app.color.hairline') })
              .fontColor($r('app.color.text_main'))
              .placeholderColor($r('app.color.text_sub'))
              .onChange((v: string) => {
                this.llmKey = v
              })
              .onSubmit(() => {
                this.saveLlmKey()
              })
              .onBlur(() => {
                this.saveLlmKey()
              })

            Text('开启后,岛灵将优先调用大模型理解你的自然语言(含模糊表达);无网络、无余额或调用失败时自动降级本地规则引擎,全部功能离线可用。Key 仅保存在本机。')
              .fontSize(10)
              .fontColor($r('app.color.text_sub'))
              .lineHeight(15)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(ZeroTheme.padM)
          .backgroundColor($r('app.color.card'))
          .borderRadius(ZeroTheme.radiusM)
          .shadow({ radius: 10, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 3 })
        }

        ForEach(this.rows, (r: SettingRow) => {
          ListItem() {
            Row() {
              Column() {
                Image($rawfile(`icons/${r.icon}.svg`))
                  .width(20).height(20).fillColor($r('app.color.text_light'))
              }
              .justifyContent(FlexAlign.Center)
              .width(38)
              .height(38)
              .borderRadius(12)
              .backgroundColor(r.tint)

              Column() {
                Text(r.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_main'))
                Text(r.desc).fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 12 })

              Text('›').fontSize(18).fontColor($r('app.color.text_sub'))
            }
            .width('100%')
            .padding(ZeroTheme.padM)
            .backgroundColor($r('app.color.card'))
            .borderRadius(ZeroTheme.radiusM)
            .onClick(() => {
              this.onRow(r.kind)
            })
          }
        }, (r: SettingRow) => r.kind)
      }
      .width('100%')
      .margin({ top: 12 })

      // 关于卡
      Column({ space: 8 }) {
        Row() {
          Column() {
            Image($rawfile('icons/ic_leaf.svg'))
              .width(22).height(22).fillColor(Color.White)
          }
          .justifyContent(FlexAlign.Center)
          .width(44)
          .height(44)
          .borderRadius(14)
          .backgroundColor($r('app.color.brand_deep'))

          Column() {
            Text('零屿 Zero Isle').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
            Text('v1.0 · 仿生有机设计 · 全离线运行').fontSize(11).fontColor($r('app.color.text_sub')).margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 12 })
        }
        .width('100%')

        Divider().color($r('app.color.hairline'))
          .margin({ top: 2, bottom: 2 })

        Text('每一次低碳选择,都在给你的岛种下一片绿。记录出行、节水节电、旧物回收、光盘行动等低碳行为,看岛屿从灰屿一步步生长为生态屿。')
          .fontSize(11)
          .fontColor($r('app.color.text_sub'))
          .lineHeight(18)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(ZeroTheme.padL)
      .backgroundColor($r('app.color.card'))
      .borderRadius(ZeroTheme.radiusL)
      .shadow({ radius: 14, color: $r('app.color.shadow_soft'), offsetX: 0, offsetY: 5 })
      .margin({ top: 12 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
  }

  pageTransition() {
    PageTransitionEnter({ duration: ZeroMotion.pageDurIn, curve: Curve.Friction })
      .opacity(0)
      .translate({ y: 16 })
    PageTransitionExit({ duration: ZeroMotion.pageDurOut, curve: Curve.Friction })
      .opacity(0)
  }
}
