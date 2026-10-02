import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { ZeroTheme } from '../../common/Theme'
import { Database } from '../../data/Database'
import { ChartPoint } from '../../components/Charts'
import { toast } from '../../common/Common'
import { SpeechService } from '../../service/SpeechService'
import { AgentService, AgentMessage, AgentCard, AgentSession, AgentTaskBrief } from '../../service/AgentService'

/** 会话持久化的单条记录(kv_store JSON) */
interface ChatRec {
  role: string
  text: string
  chips: string[]
  via: string
}

/** 气泡内嵌迷你趋势图(纯 Canvas,不依赖图表组件尺寸) */
@Component
struct MiniTrend {
  @Prop @Watch('redraw') values: number[] = []
  private ctx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true))

  redraw() {
    const c: CanvasRenderingContext2D = this.ctx
    const w: number = c.width
    const h: number = c.height
    c.clearRect(0, 0, w, h)
    const vals: number[] = this.values
    if (vals.length === 0) {
      return
    }
    let max: number = 0.0001
    for (const v of vals) {
      if (v > max) {
        max = v
      }
    }
    max = max * 1.15
    const pad: number = 8
    const iw: number = w - pad * 2
    const ih: number = h - pad * 2 - 2
    const xOf = (i: number): number => pad + iw * (vals.length === 1 ? 0.5 : i / (vals.length - 1))
    const yOf = (v: number): number => pad + ih - v / max * ih
    // 基线
    c.strokeStyle = 'rgba(14,94,111,0.15)'
    c.lineWidth = 1
    c.beginPath()
    c.moveTo(pad, pad + ih)
    c.lineTo(w - pad, pad + ih)
    c.stroke()
    // 折线
    c.strokeStyle = '#0E5E6F'
    c.lineWidth = 2
    c.beginPath()
    for (let i = 0; i < vals.length; i++) {
      if (i === 0) {
        c.moveTo(xOf(i), yOf(vals[i]))
      } else {
        c.lineTo(xOf(i), yOf(vals[i]))
      }
    }
    c.stroke()
    // 渐变填充
    c.lineTo(xOf(vals.length - 1), pad + ih)
    c.lineTo(xOf(0), pad + ih)
    c.closePath()
    c.fillStyle = 'rgba(14,94,111,0.10)'
    c.fill()
    // 末点
    c.fillStyle = '#0E5E6F'
    c.beginPath()
    c.arc(xOf(vals.length - 1), yOf(vals[vals.length - 1]), 3, 0, Math.PI * 2)
    c.fill()
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(76)
      .accessibilityText('近期减排趋势迷你折线图')
      .onReady(() => {
        this.redraw()
      })
  }
}

/**
 * 岛灵对话页:与岛灵 Agent 对话,记账 / 查数 / 建议 / 改账一句话完成。
 * 气泡流(支持富卡片)+ 快捷追问 + 打字机流式回复 + 会话持久化。
 */
@Entry
@Component
struct AgentPage {
  @State messages: AgentMessage[] = []
  @State input: string = ''
  @State busy: boolean = false
  @State streaming: boolean = false
  @State streamText: string = ''
  private scroller: Scroller = new Scroller()
  private session: AgentSession = new AgentSession()
  private streamTimer: number = -1
  @State ttsOn: boolean = false
  @State listening: boolean = false

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    Database.kvGet(ctx, 'agent_chat', '').then((raw: string) => {
      let restored: boolean = false
      if (raw.length > 0) {
        try {
          const arr = JSON.parse(raw) as Array<ChatRec>
          for (const r of arr) {
            const m = new AgentMessage()
            m.role = r.role
            m.text = r.text
            m.chips = r.chips
            m.viaLlm = r.via === 'llm'
            this.messages.push(m)
          }
          restored = this.messages.length > 0
        } catch (e) {
          restored = false
        }
      }
      if (!restored) {
        this.pushGreeting()
      }
      this.scrollToBottom()
      // 主动式:每天第一次打开岛灵,自动播报当日简报
      Database.kvGet(ctx, 'agent_brief_date', '').then((v: string) => {
        if (v !== Database.today()) {
          Database.kvSet(ctx, 'agent_brief_date', Database.today())
          this.sendText('今日简报')
        }
      })
    })
    Database.kvGet(ctx, 'agent_tts', '').then((v: string) => {
      this.ttsOn = v === '1'
    })
  }

  aboutToDisappear(): void {
    if (this.streamTimer >= 0) {
      clearInterval(this.streamTimer)
      this.streamTimer = -1
    }
  }

  private pushGreeting(): void {
    const hello = new AgentMessage()
    hello.text = '嗨,我是岛灵🧚\n你的碳账本管家:说一句话就能记账、查数、给建议~'
    hello.chips = ['记录:骑车3公里', '本周减排多少?', '今日简报', '我的岛币余额']
    this.messages.push(hello)
  }

  private pushMessage(m: AgentMessage): void {
    this.messages.push(m)
    this.saveChat()
    this.scrollToBottom()
    if (m.role === 'agent' && this.ttsOn && m.text.length > 0) {
      const ctx = getContext(this) as common.UIAbilityContext
      SpeechService.speak(ctx, m.text)
    }
  }

  private saveChat(): void {
    const ctx = getContext(this) as common.UIAbilityContext
    const out: ChatRec[] = []
    const start: number = Math.max(0, this.messages.length - 40)
    for (let i = start; i < this.messages.length; i++) {
      const m = this.messages[i]
      const r: ChatRec = { role: m.role, text: m.text, chips: m.chips, via: m.viaLlm ? 'llm' : 'rules' }
      out.push(r)
    }
    Database.kvSet(ctx, 'agent_chat', JSON.stringify(out))
  }

  private clearChat(): void {
    this.session.pendingDeleteId = -1
    this.session.pendingDeleteText = ''
    this.messages = []
    this.pushGreeting()
    this.saveChat()
    this.scrollToBottom()
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom)
    }, 80)
  }

  /** 打字机流式输出:逐字显示完成后整条入列并持久化 */
  private startStream(m: AgentMessage): void {
    if (m.text.length === 0) {
      this.pushMessage(m)
      return
    }
    this.streaming = true
    this.streamText = ''
    let i: number = 0
    this.streamTimer = setInterval(() => {
      i = Math.min(m.text.length, i + 2)
      this.streamText = m.text.slice(0, i)
      if (i % 6 === 0) {
        this.scrollToBottom()
      }
      if (i >= m.text.length) {
        clearInterval(this.streamTimer)
        this.streamTimer = -1
        this.streaming = false
        this.pushMessage(m)
      }
    }, 18)
  }

  private sendText(raw: string): void {
    const t: string = raw.trim()
    if (t.length === 0 || this.busy) {
      return
    }
    const u = new AgentMessage()
    u.role = 'user'
    u.text = t
    this.pushMessage(u)
    this.input = ''
    this.busy = true
    const ctx = getContext(this) as common.UIAbilityContext
    AgentService.reply(ctx, t, this.session).then((m: AgentMessage) => {
      this.busy = false
      this.startStream(m)
    }).catch(() => {
      const m = new AgentMessage()
      m.text = '哎呀,岛灵走神了,再试一次?'
      this.busy = false
      this.pushMessage(m)
    })
  }

  private pct(t: AgentTaskBrief): number {
    return Math.min(100, Math.round(t.value / t.goal * 100))
  }

  /** 语音输入开关:再按一次停止,识别完成自动发送 */
  private toggleVoice(): void {
    if (this.listening) {
      SpeechService.finishListening()
      this.listening = false
      return
    }
    if (this.busy || this.streaming) {
      return
    }
    this.listening = true
    const ctx = getContext(this) as common.UIAbilityContext
    SpeechService.listenOnce(ctx, {
      onPartial: (t: string) => {
        this.input = t
      },
      onFinal: (t: string) => {
        this.listening = false
        const trimmed: string = t.trim()
        if (trimmed.length > 0) {
          this.input = trimmed
          this.sendText(trimmed)
        }
      },
      onError: (msg: string) => {
        this.listening = false
        toast(msg)
      }
    })
  }

  /** 气泡通用样式 */
  @Builder
  bubble(text: string, isUser: boolean) {
    Text(text)
      .fontSize(14)
      .fontColor(isUser ? $r('app.color.text_light') : $r('app.color.text_main'))
      .lineHeight(21)
      .padding({ left: 13, right: 13, top: 9, bottom: 9 })
      .backgroundColor(isUser ? $r('app.color.primary') : $r('app.color.card_bg'))
      .borderRadius(14)
      .constraintSize({ maxWidth: '76%' })
      .border(isUser ? { width: 0 } : { width: 1, color: $r('app.color.hairline') })
  }

  /** 富卡片:迷你趋势图 / 任务进度条 */
  @Builder
  cardView(card: AgentCard) {
    Column({ space: 6 }) {
      if (card.kind === 'trend') {
        Text('📈 近期趋势').fontSize(10).fontColor($r('app.color.text_sub'))
        MiniTrend({ values: card.points.map((p: ChartPoint): number => p.value) })
      } else if (card.kind === 'tasks') {
        ForEach(card.tasks, (t: AgentTaskBrief) => {
          Row({ space: 8 }) {
            Text(t.name)
              .fontSize(11).fontColor($r('app.color.text_main'))
              .constraintSize({ maxWidth: '46%' })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%').height(6).borderRadius(3)
                .backgroundColor($r('app.color.hairline'))
              Row()
                .width(`${this.pct(t)}%`).height(6).borderRadius(3)
                .backgroundColor(t.done ? $r('app.color.life') : $r('app.color.primary'))
            }
            .layoutWeight(1)
            Text(`${t.value}/${t.goal}`)
              .fontSize(10).fontColor(t.done ? $r('app.color.life') : $r('app.color.text_sub'))
          }
          .width('100%')
        }, (t: AgentTaskBrief) => t.name)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('76%')
    .padding(10)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .border({ width: 1, color: $r('app.color.hairline') })
  }

  build() {
    Column() {
      // 顶栏
      Row({ space: 8 }) {
        Text('‹')
          .fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          .width(34).height(34).textAlign(TextAlign.Center)
          .onClick(() => {
            router.back()
          })
        Column({ space: 2 }) {
          Text('岛灵')
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_main'))
          Text('对话式碳账本管家 · 本地优先')
            .fontSize(10).fontColor($r('app.color.text_sub'))
        }
        .alignItems(HorizontalAlign.Start)

        Blank()
        Text('清空')
          .fontSize(11).fontColor($r('app.color.text_sub'))
          .padding({ left: 8, right: 8, top: 6, bottom: 6 })
          .onClick(() => {
            this.clearChat()
          })
        Text(this.ttsOn ? '🔊' : '🔇')
          .fontSize(15)
          .padding({ left: 4, right: 4, top: 6, bottom: 6 })
          .accessibilityText(this.ttsOn ? '关闭语音播报' : '开启语音播报')
          .onClick(() => {
            this.ttsOn = !this.ttsOn
            const ctx = getContext(this) as common.UIAbilityContext
            Database.kvSet(ctx, 'agent_tts', this.ttsOn ? '1' : '0')
          })
        Column() {
          Text('🧚').fontSize(16)
        }
        .width(36).height(36).borderRadius(18)
        .backgroundColor($r('app.color.primary_light'))
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding({ left: 8, right: ZeroTheme.padL, top: 10, bottom: 10 })

      // 消息流
      Scroll(this.scroller) {
        Column({ space: 12 }) {
          ForEach(this.messages, (m: AgentMessage, idx: number) => {
            Column({ space: 6 }) {
              if (m.role === 'user') {
                Row() {
                  Blank()
                  this.bubble(m.text, true)
                }
                .width('100%')
              } else {
                Row({ space: 8 }) {
                  Column() {
                    Text('🧚').fontSize(15)
                  }
                  .width(32).height(32).borderRadius(16)
                  .backgroundColor($r('app.color.primary_light'))
                  .justifyContent(FlexAlign.Center)
                  Column({ space: 6 }) {
                    this.bubble(m.text, false)
                    if (m.card !== null && m.card.kind !== 'none') {
                      this.cardView(m.card)
                    }
                    Text(m.viaLlm ? '🤖 LLM 智能理解' : '⚙️ 本地规则引擎')
                      .fontSize(9).fontColor($r('app.color.text_sub')).opacity(0.75)
                      .margin({ left: 2 })
                      .accessibilityText(m.viaLlm ? '此回复由大模型理解生成' : '此回复由本地规则引擎生成')
                  }
                  .alignItems(HorizontalAlign.Start)
                  Blank()
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
              }
              // 末条 agent 消息附带快捷追问
              if (m.role === 'agent' && !this.busy && !this.streaming &&
                idx === this.messages.length - 1 && m.chips.length > 0) {
                Scroll() {
                  Row({ space: 6 }) {
                    ForEach(m.chips, (c: string) => {
                      Text(c)
                        .fontSize(12).fontColor($r('app.color.primary'))
                        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                        .backgroundColor($r('app.color.card_bg'))
                        .borderRadius(999)
                        .border({ width: 1, color: $r('app.color.hairline') })
                        .onClick(() => {
                          this.sendText(c)
                        })
                    }, (c: string) => c)
                  }
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .width('100%')
                .margin({ left: 40 })
              }
            }
            .width('100%')
          }, (m: AgentMessage, idx: number) => idx.toString())

          // 打字机流式气泡
          if (this.streaming) {
            Row({ space: 8 }) {
              Column() {
                Text('🧚').fontSize(15)
              }
              .width(32).height(32).borderRadius(16)
              .backgroundColor($r('app.color.primary_light'))
              .justifyContent(FlexAlign.Center)
              Text(this.streamText + '▌')
                .fontSize(14).fontColor($r('app.color.text_main')).lineHeight(21)
                .padding({ left: 13, right: 13, top: 9, bottom: 9 })
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(14)
                .constraintSize({ maxWidth: '76%' })
                .border({ width: 1, color: $r('app.color.hairline') })
              Blank()
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }

          // 思考中指示
          if (this.busy && !this.streaming) {
            Row({ space: 8 }) {
              Column() {
                Text('🧚').fontSize(15)
              }
              .width(32).height(32).borderRadius(16)
              .backgroundColor($r('app.color.primary_light'))
              .justifyContent(FlexAlign.Center)
              Text('岛灵翻账本中…')
                .fontSize(13).fontColor($r('app.color.text_sub'))
                .padding({ left: 13, right: 13, top: 9, bottom: 9 })
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(14)
                .border({ width: 1, color: $r('app.color.hairline') })
              Blank()
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 6, bottom: 10 })
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.End)
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)

      // 输入区
      Row({ space: 8 }) {
        Button() {
          Text(this.listening ? '⏹' : '🎙')
            .fontSize(15)
        }
        .width(42).height(42)
        .borderRadius(21)
        .backgroundColor(this.listening ? $r('app.color.gold') : $r('app.color.card_bg'))
        .border({ width: 1, color: $r('app.color.hairline') })
        .accessibilityText(this.listening ? '停止语音输入' : '开始语音输入')
        .onClick(() => {
          this.toggleVoice()
        })

        TextInput({ text: this.input, placeholder: '跟岛灵说点什么,比如:骑车3公里' })
          .layoutWeight(1)
          .height(42)
          .borderRadius(21)
          .backgroundColor($r('app.color.card_bg'))
          .border({ width: 1, color: $r('app.color.hairline') })
          .fontSize(14)
          .fontColor($r('app.color.text_main'))
          .placeholderColor($r('app.color.text_sub'))
          .placeholderFont({ size: 13 })
          .enterKeyType(EnterKeyType.Send)
          .onChange((v: string) => {
            this.input = v
          })
          .onSubmit(() => {
            this.sendText(this.input)
          })
          .enabled(!this.busy)
        Button() {
          Text(this.busy ? '…' : '↑')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_light'))
        }
        .width(42).height(42)
        .borderRadius(21)
        .backgroundColor(this.busy ? $r('app.color.disabled_bg') : $r('app.color.primary'))
        .onClick(() => {
          this.sendText(this.input)
        })
        .enabled(!this.busy)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: 720 })
    .backgroundColor($r('app.color.bg'))
  }
}
