/**
 * 迷你动画场景条 v2(F 追代二次迭代):析/营/验各用专属元素词汇,与首页岛屿差异化
 * StatsStrip「图表山脉」:折线山脊带数据点 + 纸飞机虚线航线 + 浮动图表徽章(无太阳/草地/树)
 * CampStrip「暮色营地」:星空月牙 + 串灯 + 发光帐篷 + 篝火星星(黄昏暖紫调,区别于岛屿白日)
 * LabStrip「蓝图蒸馏台」:坐标纸网格 + 蒸馏链(烧瓶冒泡→导管→接液杯滴落) + 原子轨道 + 试管架
 * 构图遵守「文字安全区」:各页标题/数据牌所在区域只保留低对比底纹,装饰元素集中在另一侧
 * 帧循环随可见性启停(同 E2);画板豁免主题色(同 IslandScene 策略)
 */

@Component
export struct StatsStrip {
  @Prop @Watch('redraw') stage: number = 0
  private ctx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private timer: number = -1
  private running: boolean = false
  private t: number = 0

  startLoop(): void {
    if (this.running) {
      return
    }
    this.running = true
    this.timer = setInterval(() => {
      this.t += 0.05
      this.draw()
    }, 80)
  }

  stopLoop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
      this.timer = -1
    }
    this.running = false
  }

  aboutToDisappear(): void {
    this.stopLoop()
  }

  redraw() {
    this.draw()
  }

  /** 折线山脉顶点(横纵均为画布比例;右重左轻,给左下数据牌让位) */
  private peaks(): number[][] {
    return [
      [0.30, 0.80], [0.40, 0.52], [0.52, 0.68], [0.64, 0.34], [0.76, 0.58], [0.90, 0.26]
    ]
  }

  private draw() {
    const c = this.ctx
    const w: number = c.width
    const h: number = c.height
    c.clearRect(0, 0, w, h)
    const t: number = this.t
    // 1 底色:晨雾蓝青
    const sky = c.createLinearGradient(0, 0, 0, h)
    sky.addColorStop(0, '#C7E5F0')
    sky.addColorStop(1, '#E0F5E6')
    c.fillStyle = sky
    c.fillRect(0, 0, w, h)
    // 2 背景雾点(缓慢漂移的第二层)
    for (let i = 0; i < 9; i++) {
      const dx: number = (i * 89 + 20) % w + Math.sin(t * 0.5 + i) * 5
      const dy: number = (i * 47 + 14) % (h * 0.6)
      c.fillStyle = `rgba(14,94,111,${0.05 + (i % 3) * 0.02})`
      c.beginPath()
      c.arc(dx, dy, 2.2 + i % 3, 0, Math.PI * 2)
      c.fill()
    }
    // 3 折线山脉(填充 + 描边 + 顶点数据点,高亮顶点脉冲)
    const pk: number[][] = this.peaks()
    c.beginPath()
    c.moveTo(pk[0][0] * w, pk[0][1] * h)
    for (let i = 1; i < pk.length; i++) {
      c.lineTo(pk[i][0] * w, pk[i][1] * h)
    }
    c.lineTo(pk[pk.length - 1][0] * w, h)
    c.lineTo(pk[0][0] * w, h)
    c.closePath()
    const mg = c.createLinearGradient(0, h * 0.2, 0, h)
    mg.addColorStop(0, 'rgba(14,94,111,0.28)')
    mg.addColorStop(1, 'rgba(14,94,111,0.05)')
    c.fillStyle = mg
    c.fill()
    c.strokeStyle = '#177087'
    c.lineWidth = 3.5
    c.lineJoin = 'round'
    c.beginPath()
    c.moveTo(pk[0][0] * w, pk[0][1] * h)
    for (let i = 1; i < pk.length; i++) {
      c.lineTo(pk[i][0] * w, pk[i][1] * h)
    }
    c.stroke()
    // 基线 + 刻度点
    c.strokeStyle = 'rgba(23,112,135,0.5)'
    c.lineWidth = 1.5
    c.beginPath()
    c.moveTo(pk[0][0] * w - 14, h * 0.86)
    c.lineTo(w * 0.96, h * 0.86)
    c.stroke()
    for (let i = 0; i < pk.length; i++) {
      const px: number = pk[i][0] * w
      const py: number = pk[i][1] * h
      const hot: boolean = i === (Math.floor(t * 0.8) % pk.length)
      if (hot) {
        c.strokeStyle = `rgba(23,112,135,${0.5 + 0.3 * Math.sin(t * 3)})`
        c.lineWidth = 2
        c.beginPath()
        c.arc(px, py, 8 + Math.sin(t * 3) * 1.5, 0, Math.PI * 2)
        c.stroke()
      }
      c.fillStyle = '#FFFFFF'
      c.beginPath()
      c.arc(px, py, 4.5, 0, Math.PI * 2)
      c.fill()
      c.strokeStyle = '#177087'
      c.lineWidth = 2.5
      c.stroke()
    }
    // 4 纸飞机沿虚线航线飞行(左上→右上,循环淡入淡出)
    const trail = (p: number): number[] => {
      const x0: number = 0.08 * w
      const y0: number = 0.34 * h
      const cxp: number = 0.46 * w
      const cyp: number = 0.02 * h
      const x1: number = 0.88 * w
      const y1: number = 0.22 * h
      const qx: number = (1 - p) * (1 - p) * x0 + 2 * (1 - p) * p * cxp + p * p * x1
      const qy: number = (1 - p) * (1 - p) * y0 + 2 * (1 - p) * p * cyp + p * p * y1
      return [qx, qy]
    }
    c.strokeStyle = 'rgba(23,112,135,0.4)'
    c.lineWidth = 1.5
    c.setLineDash([5, 6])
    c.beginPath()
    c.moveTo(0.08 * w, 0.34 * h)
    c.quadraticCurveTo(0.46 * w, 0.02 * h, 0.88 * w, 0.22 * h)
    c.stroke()
    c.setLineDash([])
    const pp: number = (t * 0.14) % 1.2
    if (pp < 1) {
      const cur = trail(pp)
      const nxt = trail(Math.min(1, pp + 0.02))
      const ang: number = Math.atan2(nxt[1] - cur[1], nxt[0] - cur[0])
      const bob: number = Math.sin(t * 2.2) * 2
      c.save()
      c.translate(cur[0], cur[1] + bob)
      c.rotate(ang)
      c.fillStyle = '#FFFFFF'
      c.beginPath()
      c.moveTo(13, 0)
      c.lineTo(-9, -7)
      c.lineTo(-4, 0)
      c.lineTo(-9, 7)
      c.closePath()
      c.fill()
      c.fillStyle = '#BFD9D4'
      c.beginPath()
      c.moveTo(13, 0)
      c.lineTo(-4, 0)
      c.lineTo(-9, 7)
      c.closePath()
      c.fill()
      c.restore()
    }
    // 5 浮动图表徽章:迷你柱状图(左中,呼吸) + 旋转饼盘(右上)
    const badgeY: number = h * 0.4 + Math.sin(t * 1.6) * 3
    const bxc: number = w * 0.09 + 19
    const byc: number = badgeY + 15
    c.fillStyle = 'rgba(255,255,255,0.92)'
    c.beginPath()
    c.arc(bxc, byc, 19, 0, Math.PI * 2)
    c.fill()
    c.strokeStyle = 'rgba(23,112,135,0.35)'
    c.lineWidth = 1.5
    c.stroke()
    const barH: number[] = [9 + Math.sin(t * 2) * 3, 15 + Math.sin(t * 2.6 + 1) * 3, 11 + Math.sin(t * 3.1 + 2) * 3]
    for (let i = 0; i < 3; i++) {
      const bh2: number = Math.max(4, barH[i])
      c.fillStyle = ['#3BC493', '#F2B04C', '#4E8FB8'][i]
      c.fillRect(bxc - 12 + i * 8, byc + 10 - bh2, 6, bh2)
    }
    const pieX: number = w * 0.7
    const pieY: number = h * 0.16
    c.fillStyle = 'rgba(255,255,255,0.9)'
    c.beginPath()
    c.arc(pieX, pieY, 15, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = '#F2B04C'
    c.beginPath()
    c.moveTo(pieX, pieY)
    c.arc(pieX, pieY, 15, t * 0.6, t * 0.6 + Math.PI / 2)
    c.closePath()
    c.fill()
    c.fillStyle = '#177087'
    c.beginPath()
    c.moveTo(pieX, pieY)
    c.arc(pieX, pieY, 15, t * 0.6 + Math.PI, t * 0.6 + Math.PI * 1.4)
    c.closePath()
    c.fill()
    c.strokeStyle = 'rgba(23,112,135,0.35)'
    c.lineWidth = 1.5
    c.beginPath()
    c.arc(pieX, pieY, 15, 0, Math.PI * 2)
    c.stroke()
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.startLoop()
      })
      .onVisibleAreaChange([0.0, 1.0], (isExpanding: boolean, ratio: number) => {
        if (isExpanding && ratio > 0) {
          this.startLoop()
        } else if (!isExpanding && ratio <= 0) {
          this.stopLoop()
        }
      })
      .accessibilityText('数据山脉动画插画:折线山脊与纸飞机,树木化身为数据点')
  }
}

function roundRect(c: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
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
export struct CampStrip {
  private ctx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private timer: number = -1
  private running: boolean = false
  private t: number = 0

  startLoop(): void {
    if (this.running) {
      return
    }
    this.running = true
    this.timer = setInterval(() => {
      this.t += 0.05
      this.draw()
    }, 80)
  }

  stopLoop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
      this.timer = -1
    }
    this.running = false
  }

  aboutToDisappear(): void {
    this.stopLoop()
  }

  private draw() {
    const c = this.ctx
    const w: number = c.width
    const h: number = c.height
    c.clearRect(0, 0, w, h)
    const t: number = this.t
    // 1 暮色天空(暖橙→莓紫,区别于岛屿白日)
    const sky = c.createLinearGradient(0, 0, 0, h)
    sky.addColorStop(0, '#3A3157')
    sky.addColorStop(0.45, '#8A5B7E')
    sky.addColorStop(1, '#F0A878')
    c.fillStyle = sky
    c.fillRect(0, 0, w, h)
    // 2 星空(闪烁)
    for (let i = 0; i < 14; i++) {
      const sx: number = (i * 73 + 31) % w
      const sy: number = (i * 41 + 12) % (h * 0.55)
      c.fillStyle = `rgba(255,240,214,${0.35 + 0.55 * Math.abs(Math.sin(t * 1.8 + i * 1.7))})`
      c.beginPath()
      c.arc(sx, sy, 1.4 + (i % 2) * 0.8, 0, Math.PI * 2)
      c.fill()
    }
    // 3 月牙 + 光晕
    const mx: number = w * 0.09
    const my: number = h * 0.24
    c.fillStyle = 'rgba(255,236,190,0.25)'
    c.beginPath()
    c.arc(mx, my, 20, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = '#FFF0D2'
    c.beginPath()
    c.arc(mx, my, 12, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = '#6E5586'
    c.beginPath()
    c.arc(mx + 6, my - 4, 10, 0, Math.PI * 2)
    c.fill()
    // 4 远山剪影(莓紫)
    c.fillStyle = 'rgba(88,66,110,0.9)'
    c.beginPath()
    c.moveTo(0, h * 0.78)
    c.lineTo(w * 0.18, h * 0.56)
    c.lineTo(w * 0.36, h * 0.74)
    c.lineTo(w * 0.58, h * 0.5)
    c.lineTo(w * 0.78, h * 0.72)
    c.lineTo(w, h * 0.6)
    c.lineTo(w, h)
    c.lineTo(0, h)
    c.closePath()
    c.fill()
    // 5 中景松林剪影(右侧丛,左下留白给数据牌)
    c.fillStyle = '#243B3C'
    for (let i = 0; i < 4; i++) {
      const px: number = w * (0.62 + i * 0.1)
      const py: number = h * (0.72 + (i % 2) * 0.05)
      const ps: number = 0.8 + (i % 2) * 0.25
      c.beginPath()
      c.moveTo(px, py - 24 * ps)
      c.lineTo(px - 9 * ps, py)
      c.lineTo(px + 9 * ps, py)
      c.closePath()
      c.fill()
    }
    // 6 草地前景(暮色深绿)
    const gnd = c.createLinearGradient(0, h * 0.72, 0, h)
    gnd.addColorStop(0, '#2C4A40')
    gnd.addColorStop(1, '#1B332C')
    c.fillStyle = gnd
    c.beginPath()
    c.ellipse(w * 0.5, h * 1.28, w * 0.66, h * 0.52, 0, 0, Math.PI * 2)
    c.fill()
    // 7 串灯(横向垂弧,彩灯交替闪烁)
    const w1x: number = w * 0.05
    const w2x: number = w * 0.95
    c.strokeStyle = 'rgba(30,26,46,0.7)'
    c.lineWidth = 1.6
    c.beginPath()
    c.moveTo(w1x, h * 0.16)
    c.quadraticCurveTo(w * 0.5, h * 0.34, w2x, h * 0.13)
    c.stroke()
    const bulb: string[] = ['#6EE7B7', '#FBBF24', '#F9A8D4']
    for (let i = 1; i <= 6; i++) {
      const bp: number = i / 7
      const bx: number = (1 - bp) * (1 - bp) * w1x + 2 * (1 - bp) * bp * (w * 0.5) + bp * bp * w2x
      const by: number = (1 - bp) * (1 - bp) * h * 0.16 + 2 * (1 - bp) * bp * h * 0.34 + bp * bp * h * 0.13
      const on: number = 0.55 + 0.45 * Math.sin(t * 2.6 + i * 1.3)
      c.fillStyle = i % 2 === 0 ? `rgba(251,191,36,${on})` : `rgba(110,231,183,${on})`
      c.beginPath()
      c.arc(bx, by + 4, 3, 0, Math.PI * 2)
      c.fill()
      c.strokeStyle = 'rgba(30,26,46,0.7)'
      c.lineWidth = 1
      c.beginPath()
      c.moveTo(bx, by)
      c.lineTo(bx, by + 2)
      c.stroke()
      if (i % 3 === 2) {
        c.fillStyle = `rgba(249,168,212,${on})`
        c.beginPath()
        c.arc(bx, by + 4, 3, 0, Math.PI * 2)
        c.fill()
      }
    }
    // 8 帐篷(右侧,门帘透暖光)
    const tx: number = w * 0.76
    const ty: number = h * 0.9
    c.fillStyle = 'rgba(255,214,150,0.18)'
    c.beginPath()
    c.arc(tx, ty - 12, 26, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = '#E8946A'
    c.beginPath()
    c.moveTo(tx, ty - 36)
    c.lineTo(tx - 32, ty)
    c.lineTo(tx + 32, ty)
    c.closePath()
    c.fill()
    c.fillStyle = '#C46F4A'
    c.beginPath()
    c.moveTo(tx, ty - 36)
    c.lineTo(tx - 32, ty)
    c.lineTo(tx - 10, ty)
    c.closePath()
    c.fill()
    c.fillStyle = '#FFD98A'
    c.beginPath()
    c.moveTo(tx, ty - 12)
    c.lineTo(tx - 8, ty)
    c.lineTo(tx + 8, ty)
    c.closePath()
    c.fill()
    // 9 篝火(居中偏右:光晕 + 双层火苗 + 上升火星)
    const fx: number = w * 0.5
    const fy: number = h * 0.9
    c.fillStyle = `rgba(255,170,90,${0.25 + 0.12 * Math.sin(t * 4)})`
    c.beginPath()
    c.arc(fx, fy - 10, 24, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = '#5C4033'
    c.save()
    c.translate(fx, fy - 2)
    c.rotate(0.32)
    c.fillRect(-12, -2, 24, 4)
    c.rotate(-0.64)
    c.fillRect(-12, -2, 24, 4)
    c.restore()
    const flick: number = Math.sin(t * 6) * 0.2
    c.fillStyle = '#FFB86B'
    c.beginPath()
    c.moveTo(fx, fy - 27 - flick * 10)
    c.quadraticCurveTo(fx + 10, fy - 12, fx, fy - 2)
    c.quadraticCurveTo(fx - 10, fy - 12, fx, fy - 27 - flick * 10)
    c.fill()
    c.fillStyle = '#FFE08A'
    c.beginPath()
    c.moveTo(fx, fy - 16 - flick * 6)
    c.quadraticCurveTo(fx + 5.5, fy - 9, fx, fy - 3)
    c.quadraticCurveTo(fx - 5.5, fy - 9, fx, fy - 16 - flick * 6)
    c.fill()
    for (let i = 0; i < 4; i++) {
      const ph: number = ((t * 0.7 + i * 0.25) % 1)
      c.fillStyle = `rgba(255,214,138,${(1 - ph) * 0.9})`
      c.beginPath()
      c.arc(fx + Math.sin(ph * 8 + i * 2.4) * 7, fy - 16 - ph * 40, 1.6 + (1 - ph) * 1.4, 0, Math.PI * 2)
      c.fill()
    }
    // 10 烤棉花糖(白方块在小棍上,轻微晃动)
    const sx: number = fx + 26
    c.strokeStyle = '#8B5E3C'
    c.lineWidth = 2.4
    c.beginPath()
    c.moveTo(fx + 8, fy - 2)
    c.lineTo(sx + 6, fy - 20 + Math.sin(t * 2) * 2)
    c.stroke()
    c.save()
    c.translate(sx + 6, fy - 22 + Math.sin(t * 2) * 2)
    c.rotate(-0.5)
    c.fillStyle = '#FFF6E8'
    roundRect(c, -5, -5, 10, 10, 3)
    c.fill()
    c.fillStyle = 'rgba(255,190,120,0.5)'
    c.beginPath()
    c.arc(2, 2, 2.6, 0, Math.PI * 2)
    c.fill()
    c.restore()
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.startLoop()
      })
      .onVisibleAreaChange([0.0, 1.0], (isExpanding: boolean, ratio: number) => {
        if (isExpanding && ratio > 0) {
          this.startLoop()
        } else if (!isExpanding && ratio <= 0) {
          this.stopLoop()
        }
      })
      .accessibilityText('暮色营地动画插画:星空串灯帐篷与篝火')
  }
}

@Component
export struct LabStrip {
  private ctx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private timer: number = -1
  private running: boolean = false
  private t: number = 0

  startLoop(): void {
    if (this.running) {
      return
    }
    this.running = true
    this.timer = setInterval(() => {
      this.t += 0.05
      this.draw()
    }, 80)
  }

  stopLoop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
      this.timer = -1
    }
    this.running = false
  }

  aboutToDisappear(): void {
    this.stopLoop()
  }

  private draw() {
    const c = this.ctx
    const w: number = c.width
    const h: number = c.height
    c.clearRect(0, 0, w, h)
    const t: number = this.t
    // 1 薄荷底 + 坐标纸网格(实验室蓝图感;左上标题区/左下 chips 区仅有底纹,不冲突)
    const bgG = c.createLinearGradient(0, 0, 0, h)
    bgG.addColorStop(0, '#CFF0E3')
    bgG.addColorStop(1, '#E4F8D8')
    c.fillStyle = bgG
    c.fillRect(0, 0, w, h)
    c.strokeStyle = 'rgba(14,94,111,0.09)'
    c.lineWidth = 1
    for (let gx = 0; gx < w; gx += 26) {
      c.beginPath()
      c.moveTo(gx, 0)
      c.lineTo(gx, h)
      c.stroke()
    }
    for (let gy = 0; gy < h; gy += 26) {
      c.beginPath()
      c.moveTo(0, gy)
      c.lineTo(w, gy)
      c.stroke()
    }
    // 2 实验台面
    c.fillStyle = '#C2E2D2'
    c.beginPath()
    c.ellipse(w * 0.5, h * 1.18, w * 0.62, h * 0.44, 0, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = 'rgba(255,255,255,0.5)'
    c.beginPath()
    c.ellipse(w * 0.5, h * 1.1, w * 0.55, h * 0.3, 0, 0, Math.PI * 2)
    c.fill()
    // 3 后景置物架 + 三瓶(左上空出给标题,架子置右)
    const shx: number = w * 0.68
    const shy: number = h * 0.34
    c.fillStyle = 'rgba(184,214,204,0.9)'
    roundRect(c, shx - 52, shy + 16, 116, 6, 3)
    c.fill()
    // 圆底瓶
    c.fillStyle = 'rgba(255,255,255,0.85)'
    c.beginPath()
    c.arc(shx - 30, shy, 11, 0, Math.PI * 2)
    c.fill()
    c.fillRect(shx - 34, shy - 20, 3, 12)
    c.fillStyle = 'rgba(110,231,183,0.85)'
    c.beginPath()
    c.arc(shx - 30, shy + 2, 8, 0, Math.PI)
    c.fill()
    // 高瓶(金液)
    c.fillStyle = 'rgba(255,255,255,0.85)'
    roundRect(c, shx - 6, shy - 14, 14, 30, 4)
    c.fill()
    c.fillStyle = 'rgba(251,191,36,0.75)'
    roundRect(c, shx - 4, shy + 0, 10, 14, 3)
    c.fill()
    // 广口瓶(紫液)
    c.fillStyle = 'rgba(255,255,255,0.85)'
    roundRect(c, shx + 16, shy - 8, 20, 24, 4)
    c.fill()
    c.fillStyle = 'rgba(122,107,166,0.7)'
    roundRect(c, shx + 18, shy + 2, 16, 12, 3)
    c.fill()
    // 4 蒸馏链:圆底烧瓶(冒泡+加热) → 弯管 → 接液杯(滴落)
    const fx: number = w * 0.66
    const fy: number = h * 0.66
    // 加热板(呼吸光)
    c.fillStyle = 'rgba(242,166,90,0.28)'
    roundRect(c, fx - 34, fy + 26, 68, 10, 5)
    c.fill()
    c.fillStyle = `rgba(255,196,110,${0.35 + 0.15 * Math.sin(t * 3)})`
    c.beginPath()
    c.ellipse(fx, fy + 24, 26, 5, 0, 0, Math.PI * 2)
    c.fill()
    // 烧瓶体
    c.fillStyle = 'rgba(255,255,255,0.85)'
    c.beginPath()
    c.arc(fx, fy, 24, 0, Math.PI * 2)
    c.fill()
    c.fillRect(fx - 6, fy - 40, 12, 22)
    c.strokeStyle = '#9ED8DB'
    c.lineWidth = 3
    c.beginPath()
    c.arc(fx, fy, 24, 0, Math.PI * 2)
    c.stroke()
    c.strokeRect(fx - 6, fy - 42, 12, 24)
    // 液体 + 气泡
    c.fillStyle = 'rgba(110,231,183,0.8)'
    c.beginPath()
    c.arc(fx, fy + 4, 21, 0, Math.PI)
    c.fill()
    c.fillRect(fx - 21, fy - 2, 42, 4)
    for (let i = 0; i < 3; i++) {
      const ph: number = ((t * 0.5 + i * 0.36) % 1)
      c.fillStyle = `rgba(255,255,255,${0.9 - ph * 0.6})`
      c.beginPath()
      c.arc(fx + Math.sin(ph * 8 + i * 2) * 9, fy + 18 - ph * 26, 2 + (i % 2), 0, Math.PI * 2)
      c.fill()
    }
    // 弯导管(瓶口 → 右下接液杯)
    c.strokeStyle = '#9ED8DB'
    c.lineWidth = 4
    c.beginPath()
    c.moveTo(fx + 6, fy - 42)
    c.lineTo(fx + 6, fy - 54)
    c.quadraticCurveTo(fx + 6, fy - 66, fx + 22, fy - 64)
    c.quadraticCurveTo(fx + 44, fy - 60, fx + 44, fy - 30)
    c.lineTo(fx + 44, fy - 12)
    c.stroke()
    // 接液杯(液面缓涨) + 滴落水珠
    const cx2: number = fx + 44
    const cy2: number = fy - 8
    c.fillStyle = 'rgba(255,255,255,0.85)'
    roundRect(c, cx2 - 13, cy2 - 6, 26, 22, 4)
    c.fill()
    c.strokeStyle = '#9ED8DB'
    c.strokeRect(cx2 - 13, cy2 - 6, 26, 22)
    const lvl: number = 8 + Math.sin(t * 0.9) * 3
    c.fillStyle = 'rgba(110,231,183,0.7)'
    c.fillRect(cx2 - 11, cy2 + 12 - lvl, 22, lvl)
    const dph: number = (t * 0.8) % 1
    c.fillStyle = `rgba(110,231,183,${0.4 + dph * 0.6})`
    c.beginPath()
    c.ellipse(cx2, cy2 - 12 + dph * 18, 2.4, 4, 0, 0, Math.PI * 2)
    c.fill()
    // 5 试管架(中小型,居中偏左下但避开 chips 区)
    const rx: number = w * 0.34
    const ry: number = h * 0.5
    c.fillStyle = 'rgba(216,200,168,0.95)'
    roundRect(c, rx - 28, ry + 14, 60, 8, 4)
    c.fill()
    const lq: string[] = ['rgba(110,231,183,0.9)', 'rgba(251,191,36,0.9)', 'rgba(122,107,166,0.8)']
    for (let i = 0; i < 3; i++) {
      const ux: number = rx - 16 + i * 17
      c.fillStyle = 'rgba(255,255,255,0.85)'
      roundRect(c, ux - 6, ry - 12, 12, 28, 5)
      c.fill()
      c.fillStyle = lq[i]
      roundRect(c, ux - 6, ry + 4, 12, 12, 3)
      c.fill()
      c.fillStyle = 'rgba(255,255,255,0.9)'
      c.beginPath()
      c.arc(ux + Math.sin(t * 3 + i * 2) * 2, ry + 10 - ((t * 22 + i * 9) % 12), 1.6, 0, Math.PI * 2)
      c.fill()
    }
    // 6 原子轨道徽记(右上)
    const ax: number = w * 0.9
    const ay: number = h * 0.22
    c.strokeStyle = 'rgba(14,94,111,0.4)'
    c.lineWidth = 1.6
    for (let k = 0; k < 2; k++) {
      c.save()
      c.translate(ax, ay)
      c.rotate(k * Math.PI / 2 + t * 0.5)
      c.beginPath()
      c.ellipse(0, 0, 17, 7, 0, 0, Math.PI * 2)
      c.stroke()
      c.restore()
    }
    c.fillStyle = '#177087'
    c.beginPath()
    c.arc(ax, ay, 3, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = '#F2B04C'
    c.beginPath()
    c.arc(ax + 15 * Math.cos(t), ay + 7 * Math.sin(t), 2.2, 0, Math.PI * 2)
    c.fill()
    // 7 闪烁加号(中部点缀)
    for (let i = 0; i < 2; i++) {
      const a: number = 0.25 + 0.25 * Math.sin(t * 2.6 + i * 2.4)
      c.strokeStyle = `rgba(5,150,105,${a})`
      c.lineWidth = 2.4
      const px2: number = w * (0.46 + i * 0.08)
      const py2: number = h * (0.26 + i * 0.1)
      c.beginPath()
      c.moveTo(px2 - 4, py2)
      c.lineTo(px2 + 4, py2)
      c.moveTo(px2, py2 - 4)
      c.lineTo(px2, py2 + 4)
      c.stroke()
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.startLoop()
      })
      .onVisibleAreaChange([0.0, 1.0], (isExpanding: boolean, ratio: number) => {
        if (isExpanding && ratio > 0) {
          this.startLoop()
        } else if (!isExpanding && ratio <= 0) {
          this.stopLoop()
        }
      })
      .accessibilityText('蒸馏实验台动画插画:烧瓶冒泡导管滴落与原子轨道')
  }
}
