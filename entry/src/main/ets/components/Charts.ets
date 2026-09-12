/**
 * 零屿图表组件库(Canvas 自绘,零三方依赖)
 * TrendChart 折线/柱状趋势图 · PieChart 分类占比环图 · RadarChart 碳画像雷达图
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
}

/** 分类配色(与因子库五类一一对应) */
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

@Component
export struct TrendChart {
  @Prop @Watch('redraw') points: ChartPoint[] = []
  @Prop @Watch('redraw') mode: string = 'line'
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

  private draw() {
    const c = this.ctx
    const w: number = c.width
    const h: number = c.height
    c.clearRect(0, 0, w, h)
    const k: number = 1 - Math.pow(1 - this.t, 3)
    const pts: ChartPoint[] = this.points
    if (pts.length === 0) {
      c.fillStyle = '#9AAFAA'
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

    // 网格与 Y 轴标签
    c.strokeStyle = '#E2ECE9'
    c.lineWidth = 1
    c.fillStyle = '#8FA39F'
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
    c.textAlign = 'center'
    for (let i = 0; i < pts.length; i++) {
      if (i % step === 0 || i === pts.length - 1) {
        const x: number = padL + iw * (pts.length === 1 ? 0.5 : i / (pts.length - 1))
        c.fillText(pts[i].label, x, h - padB + 30)
      }
    }

    if (this.mode === 'bar') {
      const slot: number = iw / pts.length
      const barW: number = Math.min(slot * 0.55, 64)
      for (let i = 0; i < pts.length; i++) {
        const bh: number = pts[i].value * k / max * ih
        const x: number = padL + slot * i + (slot - barW) / 2
        const y: number = padT + ih - bh
        c.fillStyle = '#2E7D5B'
        c.fillRect(x, y, barW, bh)
        c.fillStyle = '#BFE0D6'
        c.fillRect(x, y, barW, Math.min(6, bh))
      }
    } else {
      // 面积渐变
      const grad = c.createLinearGradient(0, padT, 0, h - padB)
      grad.addColorStop(0, 'rgba(14,94,111,0.28)')
      grad.addColorStop(1, 'rgba(14,94,111,0.02)')
      c.beginPath()
      for (let i = 0; i < pts.length; i++) {
        const x: number = padL + iw * (pts.length === 1 ? 0.5 : i / (pts.length - 1))
        const y: number = padT + ih - pts[i].value * k / max * ih
        if (i === 0) {
          c.moveTo(x, y)
        } else {
          c.lineTo(x, y)
        }
      }
      c.strokeStyle = '#0E5E6F'
      c.lineWidth = 4
      c.stroke()
      c.lineTo(padL + iw, padT + ih)
      c.lineTo(padL, padT + ih)
      c.closePath()
      c.fillStyle = grad
      c.fill()
      // 数据点
      for (let i = 0; i < pts.length; i++) {
        const x: number = padL + iw * (pts.length === 1 ? 0.5 : i / (pts.length - 1))
        const y: number = padT + ih - pts[i].value * k / max * ih
        c.beginPath()
        c.arc(x, y, 6, 0, Math.PI * 2)
        c.fillStyle = '#FFFFFF'
        c.fill()
        c.strokeStyle = '#0E5E6F'
        c.lineWidth = 3
        c.stroke()
      }
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(190)
      .onReady(() => {
        this.redraw()
      })
  }
}

@Component
export struct PieChart {
  @Prop @Watch('redraw') slices: PieSlice[] = []
  @Prop @Watch('redraw') centerLabel: string = 'kg'
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

  private draw() {
    const c = this.ctx
    const w: number = c.width
    const h: number = c.height
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
      c.fillStyle = '#9AAFAA'
      c.font = '24px sans-serif'
      c.textAlign = 'center'
      c.fillText('暂无数据', cx, cy)
      return
    }
    let start: number = -Math.PI / 2
    for (const s of this.slices) {
      if (s.value <= 0) {
        continue
      }
      const end: number = start + s.value / total * Math.PI * 2 * k
      c.beginPath()
      c.moveTo(cx, cy)
      c.arc(cx, cy, r, start, end)
      c.closePath()
      c.fillStyle = s.color
      c.fill()
      start = end
    }
    // 中心挖孔
    c.beginPath()
    c.arc(cx, cy, r * 0.6, 0, Math.PI * 2)
    c.fillStyle = '#FFFFFF'
    c.fill()
    c.fillStyle = '#17322F'
    c.font = 'bold 30px sans-serif'
    c.textAlign = 'center'
    c.fillText(total >= 100 ? total.toFixed(0) : total.toFixed(1), cx, cy + 2)
    c.fillStyle = '#8FA39F'
    c.font = '20px sans-serif'
    c.fillText(this.centerLabel, cx, cy + 30)
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(190)
      .onReady(() => {
        this.redraw()
      })
  }
}

@Component
export struct RadarChart {
  @Prop @Watch('redraw') values: number[] = []
  @Prop @Watch('redraw') labels: string[] = []
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
    c.clearRect(0, 0, w, h)
    const cx: number = w / 2
    const cy: number = h / 2 + 6
    const R: number = Math.min(w, h) / 2 - 52
    if (this.values.length < 5) {
      return
    }
    // 网格环
    c.strokeStyle = '#DCE8E4'
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
    // 轴线与标签
    c.fillStyle = '#6B7F7C'
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
    c.fillStyle = 'rgba(14,94,111,0.30)'
    c.fill()
    c.strokeStyle = '#0E5E6F'
    c.lineWidth = 3
    c.stroke()
    // 顶点
    for (let i = 0; i < 5; i++) {
      const v: number = Math.min(1, Math.max(0.04, this.values[i])) * (1 - Math.pow(1 - this.t, 3))
      const p = this.pt(cx, cy, R * v, i)
      c.beginPath()
      c.arc(p[0], p[1], 6, 0, Math.PI * 2)
      c.fillStyle = '#0E5E6F'
      c.fill()
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(220)
      .onReady(() => {
        this.redraw()
      })
  }
}

/** 进度环(任务卡用) */
@Component
export struct RingProgress {
  @Prop @Watch('redraw') value: number = 0
  @Prop @Watch('redraw') total: number = 1
  @Prop color: string = '#059669'
  private ctx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true))

  redraw() {
    this.draw()
  }

  private draw() {
    const c = this.ctx
    const w: number = c.width
    const h: number = c.height
    c.clearRect(0, 0, w, h)
    const cx: number = w / 2
    const cy: number = h / 2
    const r: number = Math.min(w, h) / 2 - 6
    c.lineWidth = 5
    c.lineCap = 'round'
    c.strokeStyle = '#E2EFE7'
    c.beginPath()
    c.arc(cx, cy, r, 0, Math.PI * 2)
    c.stroke()
    const pct: number = this.total > 0 ? Math.min(1, this.value / this.total) : 0
    if (pct > 0) {
      c.strokeStyle = this.color
      c.beginPath()
      c.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + pct * Math.PI * 2)
      c.stroke()
    }
    c.fillStyle = '#475569'
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
  }
}
