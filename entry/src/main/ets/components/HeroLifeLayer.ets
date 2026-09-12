/**
 * Hero 生命层:叠加在实景 Hero 图上的透明动画层
 * 海鸟飞过 · 云雾缓移 · 落叶(绿屿+) · 萤火虫(森屿+)
 * 与 IslandScene 同源的生态动画语言,让静态照片"活"起来
 */
@Component
export struct HeroLifeLayer {
  @Prop stage: number = 0
  private ctx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private timer: number = -1

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      this.draw()
    }, 60)
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
    }
  }

  private bird(c: CanvasRenderingContext2D, x: number, y: number, flap: number, s: number): void {
    c.strokeStyle = 'rgba(40,70,64,0.75)'
    c.lineWidth = 2.2 * s
    c.beginPath()
    c.moveTo(x - 8 * s, y)
    c.quadraticCurveTo(x - 3 * s, y - 5 * s - flap, x, y)
    c.quadraticCurveTo(x + 3 * s, y - 5 * s - flap, x + 8 * s, y)
    c.stroke()
  }

  private mist(c: CanvasRenderingContext2D, x: number, y: number, wSeg: number, alpha: number): void {
    c.fillStyle = `rgba(255,255,255,${alpha})`
    c.beginPath()
    c.ellipse(x, y, wSeg, 10, 0, 0, Math.PI * 2)
    c.fill()
  }

  private leaf(c: CanvasRenderingContext2D, x: number, y: number, rot: number, s: number, color: string): void {
    c.save()
    c.translate(x, y)
    c.rotate(rot)
    c.fillStyle = color
    c.beginPath()
    c.ellipse(0, 0, 6 * s, 2.6 * s, 0, 0, Math.PI * 2)
    c.fill()
    c.restore()
  }

  private draw(): void {
    const c = this.ctx
    const w: number = c.width
    const h: number = c.height
    const t: number = Date.now() / 1000
    c.clearRect(0, 0, w, h)

    // 云雾缓移(两条柔白横雾,慢速)
    this.mist(c, ((t * 9) % (w + 320)) - 160, h * 0.52, w * 0.22, 0.10)
    this.mist(c, w - ((t * 6 + 200) % (w + 320)) + 160, h * 0.60, w * 0.18, 0.08)

    // 海鸟 ×2(横穿天空,振翅)
    this.bird(c, ((t * 30) % (w + 80)) - 40, h * (0.24 + Math.sin(t * 1.3) * 0.02), Math.sin(t * 7) * 3, 1.0)
    this.bird(c, w - ((t * 22 + 120) % (w + 80)) + 40, h * (0.34 + Math.sin(t * 1.1 + 2) * 0.025), Math.sin(t * 6.2 + 1) * 3, 0.75)

    // 落叶(绿屿+)
    if (this.stage >= 2) {
      const lx: number = w * 0.3 + Math.sin(t * 0.9) * 30
      const ly: number = h * (0.30 + ((t * 26) % (h * 0.4)))
      this.leaf(c, lx, ly, t * 2.4, 1.1, 'rgba(158,150,90,0.75)')
      const lx2: number = w * 0.68 + Math.sin(t * 0.7 + 3) * 24
      const ly2: number = h * (0.22 + ((t * 20 + 200) % (h * 0.45)))
      this.leaf(c, lx2, ly2, -t * 2.0, 0.9, 'rgba(120,150,90,0.7)')
    }

    // 萤火虫(森屿+):金点游走 + 呼吸发光
    if (this.stage >= 3) {
      for (let i = 0; i < 4; i++) {
        const fx: number = w * (0.16 + 0.22 * i) + Math.sin(t * (0.8 + i * 0.3) + i * 2) * 40
        const fy: number = h * (0.42 + (i % 2) * 0.16) + Math.cos(t * (0.6 + i * 0.2) + i) * 26
        const glow: number = 0.35 + 0.3 * (0.5 + 0.5 * Math.sin(t * 2.2 + i * 1.7))
        c.fillStyle = `rgba(251,191,36,${glow})`
        c.beginPath()
        c.arc(fx, fy, 3.2, 0, Math.PI * 2)
        c.fill()
        c.fillStyle = `rgba(251,191,36,${glow * 0.25})`
        c.beginPath()
        c.arc(fx, fy, 8, 0, Math.PI * 2)
        c.fill()
      }
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
      .onReady(() => {
        this.draw()
      })
  }
}
