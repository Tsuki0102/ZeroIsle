/**
 * 零屿图表组件库(Canvas 自绘,零三方依赖)
 * TrendChart 折线/柱状趋势图(点击高亮+气泡) · PieChart 分类占比环图(点击扇区弹出)
 * RadarChart 碳画像雷达(顶点数值) · RingProgress 进度环 · AnimatedNumber 数字滚动动效
 * 配色跟随应用深浅色(AppStorage.darkOn,Canvas 内不使用资源色)
 */

export class ChartPoint {
  label: string = ''
  value: number = 0
}

export class PieSlice {
  label: string = ''
  value: number = 0
  color: string = '#2E7D5B'
  icon: string = ''
  /** 分类 id(看板分类筛选与下钻用) */
  id: string = ''
}

/** 分类配色(与因子库五类一一对应;中度饱和,深浅两主题下均可辨) */
export function catColor(categoryId: string): string {
  if (categoryId === 'travel') {
    return '#2E7D5B'
  }
  if (categoryId === 'energy') {
    return '#F2B04C'
  }
  if (categoryId === 'food') {
    return '#D96C5F'
  }
  if (categoryId === 'recycle') {
    return '#4E8FB8'
  }
  return '#7A6BA6'
}

/** 图表调色板(深浅双主题) */
interface ChartPalette {
  grid: string
  axis: string
  empty: string
  bar: string
  barTop: string
  line: string
  area0: string
  area1: string
  dot: string
  bubbleBg: string
  bubbleText: string
  hole: string
  centerText: string
  centerLabel: string
  radarGrid: string
  radarLabel: string
  radarFill: string
  radarStroke: string
  ringTrack: string
  ringText: string
}

const CHART_LIGHT: ChartPalette = {
  grid: '#E2ECE9', axis: '#8FA39F', empty: '#9AAFAA',
  bar: '#2E7D5B', barTop: '#BFE0D6',
  line: '#0E5E6F', area0: 'rgba(14,94,111,0.28)', area1: 'rgba(14,94,111,0.02)', dot: '#FFFFFF',
  bubbleBg: 'rgba(15,23,42,0.88)', bubbleText: '#FFFFFF',
  hole: '#FFFFFF', centerText: '#17322F', centerLabel: '#8FA39F',
  radarGrid: '#DCE8E4', radarLabel: '#6B7F7C',
  radarFill: 'rgba(14,94,111,0.30)', radarStroke: '#0E5E6F',
  ringTrack: '#E2EFE7', ringText: '#475569'
}

const CHART_DARK: ChartPalette = {
  grid: '#26332D', axis: '#8FA79E', empty: '#6C837B',
  bar: '#3BC493', barTop: '#1F4A3C',
  line: '#3BC493', area0: 'rgba(59,196,147,0.26)', area1: 'rgba(59,196,147,0.02)', dot: '#16211B',
  bubbleBg: 'rgba(232,241,236,0.94)', bubbleText: '#10201B',
  hole: '#16211B', centerText: '#E8F1EC', centerLabel: '#8FA79E',
  radarGrid: '#26332D', radarLabel: '#93A8A0',
  radarFill: 'rgba(59,196,147,0.26)', radarStroke: '#3BC493',
  ringTrack: '#26332D', ringText: '#9CB3AA'
}

/** 圆角矩形路径(Canvas 无原生 roundRect 的兼容实现) */
function roundRectPath(c: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
  const rr: number = Math.min(r, w / 2, h / 2)
  c.beginPath()
  c.moveTo(x + rr, y)
  c.lineTo(x + w - rr, y)
  c.quadraticCurveTo(x + w, y, x + w, y + rr)
  c.lineTo(x + w, y + h - rr)
  c.quadraticCurveTo(x + w, y + h, x + w - rr, y + h)
  c.lineTo(x + rr, y + h)
  c.quadraticCurveTo(x, y + h, x, y + h - rr)
  c.lineTo(x, y + rr)
  c.quadraticCurveTo(x, y, x + rr, y)
  c.closePath()
}

@Component
export struct TrendChart {
  @Prop @Watch('redraw') points: ChartPoint[] = []
  @Prop @Watch('redraw') mode: string = 'line'
  @Prop unit: string = 'kg'
  @StorageProp('darkOn') @Watch('redraw') darkOn: boolean = false
  @State private sel: number = -1
  private ctx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private t: number = 0
  private timer: number = -1

  redraw() {
    this.t = 0
    this.runAnim()
  }

  private runAnim(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
    }
    this.timer = setInterval(() => {
      this.t = Math.min(1, this.t + 0.09)
      this.draw()
      if (this.t >= 1) {
        clearInterval(this.timer)
      }
    }, 30)
  }

  /** 点击命中:就近数据点选中/取消(D2) */
  private onTap(e: ClickEvent): void {
    const n: number = this.points.length
    if (n === 0) {
      return
    }
    const w: number = this.ctx.width
    const padL: number = 76
    const padR: number = 18
    const iw: number = w - padL - padR
    const idx: number = Math.round((e.x - padL) / (iw / Math.max(1, n - 1)))
    const hit: number = Math.max(0, Math.min(n - 1, idx))
    this.sel = this.sel === hit ? -1 : hit
    this.draw()
  }

  private summary(): string {
    let max = 0
    for (const p of this.points) {
      if (p.value > max) {
        max = p.value
      }
    }
    return `趋势图,共${this.points.length}个数据点,峰值${max.toFixed(1)}${this.unit}`
  }

  private draw() {
    const c = this.ctx
    const w: number = c.width
    const h: number = c.height
    const pal: ChartPalette = this.darkOn ? CHART_DARK : CHART_LIGHT
    c.clearRect(0, 0, w, h)
    const k: number = 1 - Math.pow(1 - this.t, 3)
    const pts: ChartPoint[] = this.points
    if (pts.length === 0) {
      c.fillStyle = pal.empty
      c.font = '26px sans-serif'
      c.textAlign = 'center'
      c.fillText('暂无数据', w / 2, h / 2)
      return
    }
    const padL: number = 76
    const padR: number = 18
    const padT: number = 22
    const padB: number = 46
    const iw: number = w - padL - padR
    const ih: number = h - padT - padB
    let max: number = 0.0001
    for (const p of pts) {
      if (p.value > max) {
        max = p.value
      }
    }
    max = max * 1.15
    const xOf = (i: number): number => padL + iw * (pts.length === 1 ? 0.5 : i / (pts.length - 1))
    const yOf = (v: number): number => padT + ih - v * k / max * ih

    // 网格与 Y 轴标签
    c.strokeStyle = pal.grid
    c.lineWidth = 1
    c.fillStyle = pal.axis
    c.font = '20px sans-serif'
    c.textAlign = 'right'
    for (let i = 0; i <= 2; i++) {
      const y: number = padT + ih * i / 2
      c.beginPath()
      c.moveTo(padL, y)
      c.lineTo(w - padR, y)
      c.stroke()
      const v: number = max * (1 - i / 2)
      c.fillText(v >= 10 ? v.toFixed(0) : v.toFixed(1), padL - 10, y + 7)
    }

    // X 轴标签(最多显示 6 个)
    const step: number = Math.ceil(pts.length / 6)
    c.fillStyle = pal.axis
    c.textAlign = 'center'
    for (let i = 0; i < pts.length; i++) {
      if (i % step === 0 || i === pts.length - 1) {
        c.fillText(pts[i].label, xOf(i), h - padB + 30)
      }
    }

    // 选中高亮辅助线
    if (this.sel >= 0 && this.sel < pts.length) {
      c.strokeStyle = pal.axis
      c.lineWidth = 1.5
      c.setLineDash([6, 5])
      c.beginPath()
      c.moveTo(xOf(this.sel), padT)
      c.lineTo(xOf(this.sel), padT + ih)
      c.stroke()
      c.setLineDash([])
    }

    if (this.mode === 'bar') {
      const slot: number = iw / pts.length
      const barW: number = Math.min(slot * 0.55, 64)
      for (let i = 0; i < pts.length; i++) {
        const bh: number = pts[i].value * k / max * ih
        const x: number = padL + slot * i + (slot - barW) / 2
        const y: number = padT + ih - bh
        c.fillStyle = this.sel === i ? pal.line : pal.bar
        c.fillRect(x, y, barW, bh)
        c.fillStyle = pal.barTop
        c.fillRect(x, y, barW, Math.min(6, bh))
      }
    } else {
      // 面积渐变
      const grad = c.createLinearGradient(0, padT, 0, h - padB)
      grad.addColorStop(0, pal.area0)
      grad.addColorStop(1, pal.area1)
      c.beginPath()
      for (let i = 0; i < pts.length; i++) {
        if (i === 0) {
          c.moveTo(xOf(i), yOf(pts[i].value))
        } else {
          c.lineTo(xOf(i), yOf(pts[i].value))
        }
      }
      c.strokeStyle = pal.line
      c.lineWidth = 4
      c.stroke()
      c.lineTo(padL + iw, padT + ih)
      c.lineTo(padL, padT + ih)
      c.closePath()
      c.fillStyle = grad
      c.fill()
      // 数据点
      for (let i = 0; i < pts.length; i++) {
        c.beginPath()
        c.arc(xOf(i), yOf(pts[i].value), this.sel === i ? 8 : 6, 0, Math.PI * 2)
        c.fillStyle = this.sel === i ? pal.line : pal.dot
        c.fill()
        c.strokeStyle = pal.line
        c.lineWidth = 3
        c.stroke()
      }
    }

    // 数值气泡(D2)
    if (this.sel >= 0 && this.sel < pts.length) {
      const px: number = xOf(this.sel)
      const py: number = yOf(pts[this.sel].value)
      const label: string = `${pts[this.sel].label}  ${pts[this.sel].value.toFixed(2)} ${this.unit}`
      c.font = 'bold 20px sans-serif'
      const tw: number = c.measureText(label).width + 24
      let bx: number = px - tw / 2
      bx = Math.max(4, Math.min(w - tw - 4, bx))
      const by: number = Math.max(4, py - 52)
      c.fillStyle = pal.bubbleBg
      roundRectPath(c, bx, by, tw, 36, 10)
      c.fill()
      c.fillStyle = pal.bubbleText
      c.textAlign = 'center'
      c.fillText(label, bx + tw / 2, by + 24)
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(190)
      .onReady(() => {
        this.redraw()
      })
      .onClick((e: ClickEvent) => {
        this.onTap(e)
      })
      .accessibilityText(this.summary())
  }
}

@Component
export struct PieChart {
  @Prop @Watch('redraw') slices: PieSlice[] = []
  @Prop @Watch('redraw') centerLabel: string = 'kg'
  @StorageProp('darkOn') @Watch('redraw') darkOn: boolean = false
  @State private sel: number = -1
  private ctx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private t: number = 0
  private timer: number = -1
  /** 绘制时记录的扇区角度区间(点击命中用) */
  private ranges: number[][] = []

  redraw() {
    this.t = 0
    this.runAnim()
  }

  private runAnim(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
    }
    this.timer = setInterval(() => {
      this.t = Math.min(1, this.t + 0.09)
      this.draw()
      if (this.t >= 1) {
        clearInterval(this.timer)
      }
    }, 30)
  }

  private onTap(e: ClickEvent): void {
    const w: number = this.ctx.width
    const h: number = this.ctx.height
    const cx: number = w / 2
    const cy: number = h / 2
    const r: number = Math.min(w, h) / 2 - 12
    const dx: number = e.x - cx
    const dy: number = e.y - cy
    const dist: number = Math.sqrt(dx * dx + dy * dy)
    if (dist < r * 0.6 || dist > r) {
      if (this.sel >= 0) {
        this.sel = -1
        this.draw()
      }
      return
    }
    let ang: number = Math.atan2(dy, dx)
    const idx: number = this.ranges.findIndex((rg: number[]) => ang >= rg[0] && ang < rg[1])
    this.sel = idx >= 0 ? (this.sel === idx ? -1 : idx) : -1
    this.draw()
  }

  private summary(): string {
    let total = 0
    for (const s of this.slices) {
      total += s.value
    }
    return `分类占比环图,共${this.slices.length}类,合计${total.toFixed(1)}${this.centerLabel},点击可查看明细`
  }

  private draw() {
    const c = this.ctx
    const w: number = c.width
    const h: number = c.height
    const pal: ChartPalette = this.darkOn ? CHART_DARK : CHART_LIGHT
    c.clearRect(0, 0, w, h)
    const k: number = 1 - Math.pow(1 - this.t, 3)
    const cx: number = w / 2
    const cy: number = h / 2
    const r: number = Math.min(w, h) / 2 - 12
    let total: number = 0
    for (const s of this.slices) {
      total += s.value
    }
    if (total <= 0) {
      c.fillStyle = pal.empty
      c.font = '24px sans-serif'
      c.textAlign = 'center'
      c.fillText('暂无数据', cx, cy)
      return
    }
    this.ranges = []
    let start: number = -Math.PI / 2
    for (let i = 0; i < this.slices.length; i++) {
      const s: PieSlice = this.slices[i]
      if (s.value <= 0) {
        continue
      }
      const end: number = start + s.value / total * Math.PI * 2 * k
      this.ranges.push([start, end])
      const mid: number = (start + end) / 2
      const off: number = this.sel === i ? 8 : 0
      const ox: number = Math.cos(mid) * off
      const oy: number = Math.sin(mid) * off
      c.beginPath()
      c.moveTo(cx + ox, cy + oy)
      c.arc(cx + ox, cy + oy, r, start, end)
      c.closePath()
      c.fillStyle = s.color
      c.fill()
      start = end
    }
    // 中心挖孔与文字(选中时呈现该类明细)
    c.beginPath()
    c.arc(cx, cy, r * 0.6, 0, Math.PI * 2)
    c.fillStyle = pal.hole
    c.fill()
    c.fillStyle = pal.centerText
    c.font = 'bold 30px sans-serif'
    c.textAlign = 'center'
    if (this.sel >= 0 && this.sel < this.slices.length && this.slices[this.sel].value > 0) {
      const s: PieSlice = this.slices[this.sel]
      const pct: number = Math.round(s.value / total * 100)
      c.fillText(`${pct}%`, cx, cy - 4)
      c.fillStyle = pal.centerLabel
      c.font = '18px sans-serif'
      c.fillText(`${s.label} ${s.value.toFixed(1)}`, cx, cy + 22)
    } else {
      c.fillText(total >= 100 ? total.toFixed(0) : total.toFixed(1), cx, cy + 2)
      c.fillStyle = pal.centerLabel
      c.font = '20px sans-serif'
      c.fillText(this.centerLabel, cx, cy + 30)
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(190)
      .onReady(() => {
        this.redraw()
      })
      .onClick((e: ClickEvent) => {
        this.onTap(e)
      })
      .accessibilityText(this.summary())
  }
}

@Component
export struct RadarChart {
  @Prop @Watch('redraw') values: number[] = []
  @Prop @Watch('redraw') labels: string[] = []
  @StorageProp('darkOn') @Watch('redraw') darkOn: boolean = false
  private ctx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private t: number = 0
  private timer: number = -1

  redraw() {
    this.t = 0
    this.runAnim()
  }

  private runAnim(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
    }
    this.timer = setInterval(() => {
      this.t = Math.min(1, this.t + 0.09)
      this.draw()
      if (this.t >= 1) {
        clearInterval(this.timer)
      }
    }, 30)
  }

  private pt(cx: number, cy: number, r: number, i: number): number[] {
    const ang: number = -Math.PI / 2 + i * Math.PI * 2 / 5
    return [cx + r * Math.cos(ang), cy + r * Math.sin(ang)]
  }

  private draw() {
    const c = this.ctx
    const w: number = c.width
    const h: number = c.height
    const pal: ChartPalette = this.darkOn ? CHART_DARK : CHART_LIGHT
    c.clearRect(0, 0, w, h)
    const cx: number = w / 2
    const cy: number = h / 2 + 6
    const R: number = Math.min(w, h) / 2 - 52
    if (this.values.length < 5) {
      return
    }
    // 网格环
    c.strokeStyle = pal.radarGrid
    c.lineWidth = 1
    for (let k = 1; k <= 3; k++) {
      c.beginPath()
      for (let i = 0; i < 5; i++) {
        const p = this.pt(cx, cy, R * k / 3, i)
        if (i === 0) {
          c.moveTo(p[0], p[1])
        } else {
          c.lineTo(p[0], p[1])
        }
      }
      c.closePath()
      c.stroke()
    }
    // 轴线与维度标签(D2:维度可读 + 顶点百分比)
    c.strokeStyle = pal.radarGrid
    c.fillStyle = pal.radarLabel
    c.font = '22px sans-serif'
    for (let i = 0; i < 5; i++) {
      const p = this.pt(cx, cy, R, i)
      c.beginPath()
      c.moveTo(cx, cy)
      c.lineTo(p[0], p[1])
      c.stroke()
      const lp = this.pt(cx, cy, R + 30, i)
      c.textAlign = 'center'
      c.fillText(this.labels[i], lp[0], lp[1] + 8)
    }
    // 数据多边形
    c.beginPath()
    for (let i = 0; i < 5; i++) {
      const v: number = Math.min(1, Math.max(0.04, this.values[i])) * (1 - Math.pow(1 - this.t, 3))
      const p = this.pt(cx, cy, R * v, i)
      if (i === 0) {
        c.moveTo(p[0], p[1])
      } else {
        c.lineTo(p[0], p[1])
      }
    }
    c.closePath()
    c.fillStyle = pal.radarFill
    c.fill()
    c.strokeStyle = pal.radarStroke
    c.lineWidth = 3
    c.stroke()
    // 顶点 + 百分比数值
    for (let i = 0; i < 5; i++) {
      const v: number = Math.min(1, Math.max(0.04, this.values[i])) * (1 - Math.pow(1 - this.t, 3))
      const p = this.pt(cx, cy, R * v, i)
      c.beginPath()
      c.arc(p[0], p[1], 6, 0, Math.PI * 2)
      c.fillStyle = pal.radarStroke
      c.fill()
      const lp = this.pt(cx, cy, R, i)
      c.fillStyle = pal.radarLabel
      c.font = '16px sans-serif'
      c.fillText(`${Math.round(Math.min(1, Math.max(0, this.values[i])) * 100)}%`, lp[0], lp[1] - 6)
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(220)
      .onReady(() => {
        this.redraw()
      })
      .accessibilityText('五维碳画像雷达图,展示各类低碳行为减排均衡度')
  }
}

/** 进度环(任务卡用) */
@Component
export struct RingProgress {
  @Prop @Watch('redraw') value: number = 0
  @Prop @Watch('redraw') total: number = 1
  @Prop done: boolean = false
  @StorageProp('darkOn') @Watch('redraw') darkOn: boolean = false
  private ctx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true))

  redraw() {
    this.draw()
  }

  private draw() {
    const c = this.ctx
    const w: number = c.width
    const h: number = c.height
    const pal: ChartPalette = this.darkOn ? CHART_DARK : CHART_LIGHT
    c.clearRect(0, 0, w, h)
    const cx: number = w / 2
    const cy: number = h / 2
    const r: number = Math.min(w, h) / 2 - 6
    c.lineWidth = 5
    c.lineCap = 'round'
    c.strokeStyle = pal.ringTrack
    c.beginPath()
    c.arc(cx, cy, r, 0, Math.PI * 2)
    c.stroke()
    const pct: number = this.total > 0 ? Math.min(1, this.value / this.total) : 0
    if (pct > 0) {
      c.strokeStyle = this.done ? (this.darkOn ? '#3BC493' : '#059669') : (this.darkOn ? '#177087' : '#0E5E6F')
      c.beginPath()
      c.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + pct * Math.PI * 2)
      c.stroke()
    }
    c.fillStyle = pal.ringText
    c.font = '20px sans-serif'
    c.textAlign = 'center'
    c.fillText(`${Math.round(pct * 100)}%`, cx, cy + 7)
  }

  build() {
    Canvas(this.ctx)
      .width(52)
      .height(52)
      .onReady(() => {
        this.draw()
      })
      .accessibilityText(`任务进度${Math.round(Math.min(1, this.total > 0 ? this.value / this.total : 0) * 100)}%`)
  }
}

/** 数字滚动动效(D3):核心指标变化时缓动过渡 */
@Component
export struct AnimatedNumber {
  @Prop @Watch('restart') value: number = 0
  @Prop digits: number = 0
  @Prop numSize: number = 22
  @Prop weight: FontWeight = FontWeight.Bold
  @Prop color: ResourceColor = $r('app.color.text_main')
  @Prop font: string = 'NunitoDisplay'
  @State private shown: number = 0
  private timer: number = -1
  private from: number = 0
  private t: number = 1

  aboutToAppear(): void {
    this.shown = this.value
    this.t = 1
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
      this.timer = -1
    }
  }

  restart() {
    this.from = this.shown
    this.t = 0
    if (this.timer >= 0) {
      clearInterval(this.timer)
    }
    this.timer = setInterval(() => {
      this.t = Math.min(1, this.t + 0.08)
      const k: number = 1 - Math.pow(1 - this.t, 3)
      this.shown = this.from + (this.value - this.from) * k
      if (this.t >= 1) {
        clearInterval(this.timer)
        this.timer = -1
      }
    }, 30)
  }

  build() {
    Text(this.shown.toFixed(this.digits))
      .fontSize(this.numSize)
      .fontWeight(this.weight)
      .fontColor(this.color)
      .fontFamily(this.font)
  }
}
