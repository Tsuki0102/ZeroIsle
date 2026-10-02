
/**
 * 岛屿场景 v7「五时五岛」:每个阶段=独立的天光/海色/标志性物种
 * s0 灰屿:阴冷荒原·乌鸦枯树 + 盘旋鸦群/低空冷雾/地平线冷光/希望之芽/飘散枯叶(冷灰降饱和)
 * s1 青屿:破晓微光·初绿希望 + 丁达尔光束/晨霭/光尘/破土嫩芽/海面日影粼光(柔和晨光)
 * s2 绿屿:正午盛绿·帆船码头 + 系泊小船与系缆/岸边浪花/帆船尾迹/海面光柱/更近的鸟群(明亮饱和)
 * s3 森屿:金色黄昏·风车萤火(夕阳暖调)
 * s4 生态屿:热带天堂·彩虹鲸跃瀑布(高饱和鲜艳)
 */
interface StageSkin {
  skyTop: string
  skyBottom: string
  seaTop: string
  sea: string
  island: string
  islandLight: string
  canopy: string
  canopyDeep: string
  trees: number
  /** 全屏调色(色彩分级,每阶段不同情绪) */
  grade: string
  sunVisible: boolean
  sunColor: string
  sunY: number
  sunR: number
}

const SKINS: StageSkin[] = [
  { skyTop: '#A9B2B9', skyBottom: '#D6D8D0', seaTop: '#9DB4B4', sea: '#8FA9A8', island: '#A39A87', islandLight: '#BFB6A2', canopy: '#7E766A', canopyDeep: '#5F584D', trees: 1, grade: 'rgba(100,115,128,0.16)', sunVisible: false, sunColor: '#FFFFFF', sunY: 0.2, sunR: 12 },
  { skyTop: '#F6D9C8', skyBottom: '#FBEFDC', seaTop: '#B8DCD8', sea: '#9FCEC6', island: '#8FBC7A', islandLight: '#C8E0A8', canopy: '#5FA573', canopyDeep: '#47865B', trees: 2, grade: 'rgba(255,190,150,0.07)', sunVisible: true, sunColor: 'rgba(255,200,170,0.85)', sunY: 0.26, sunR: 13 },
  { skyTop: '#9ED4F0', skyBottom: '#EAF6E0', seaTop: '#7CC8D2', sea: '#6FC0C8', island: '#4F9D63', islandLight: '#8FCB88', canopy: '#2E7D5B', canopyDeep: '#1F5A40', trees: 4, grade: 'rgba(255,235,150,0.04)', sunVisible: true, sunColor: 'rgba(255,220,110,1)', sunY: 0.12, sunR: 20 },
  { skyTop: '#F7CD96', skyBottom: '#FBE8C8', seaTop: '#D8C89A', sea: '#9FBCA8', island: '#2F6B4F', islandLight: '#5C9A6E', canopy: '#1D5A42', canopyDeep: '#14432F', trees: 7, grade: 'rgba(255,150,70,0.13)', sunVisible: true, sunColor: 'rgba(255,154,60,0.95)', sunY: 0.34, sunR: 30 },
  { skyTop: '#8ED4F2', skyBottom: '#FFF7E0', seaTop: '#6FCBD3', sea: '#4FB8C4', island: '#2E7D5F', islandLight: '#66BB8A', canopy: '#1B5E43', canopyDeep: '#114A34', trees: 10, grade: 'rgba(80,220,200,0.05)', sunVisible: true, sunColor: 'rgba(255,240,180,0.95)', sunY: 0.12, sunR: 18 }
]

const TREE_SLOTS: number[][] = [
  [0.40, 0.10], [0.56, 0.06], [0.30, 0.22], [0.64, 0.20], [0.48, 0.02],
  [0.24, 0.16], [0.70, 0.10], [0.52, 0.24], [0.36, 0.30], [0.62, 0.32]
]

@Component
export struct IslandScene {
  @Prop @Watch('redraw') stage: number = 0
  @Prop @Watch('onGrow') growPulse: number = 0
  private ctx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private timer: number = -1
  private running: boolean = false
  private pulseVal: number = 0

  onGrow(): void {
    this.pulseVal = 1
  }

  /** 帧循环只在组件可见时运行(E2):挂起页/被路由页遮挡时暂停,省电 */
  private startLoop(): void {
    if (this.running) {
      return
    }
    this.running = true
    this.timer = setInterval(() => {
      this.draw()
    }, 80)
  }

  private stopLoop(): void {
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

  private cloud(c: CanvasRenderingContext2D, x: number, y: number, s: number, alpha: number, dark: boolean): void {
    c.fillStyle = dark ? `rgba(120,132,140,${alpha})` : `rgba(255,255,255,${alpha})`
    c.beginPath()
    c.arc(x, y, 18 * s, 0, Math.PI * 2)
    c.arc(x + 22 * s, y - 8 * s, 22 * s, 0, Math.PI * 2)
    c.arc(x + 46 * s, y, 16 * s, 0, Math.PI * 2)
    c.fill()
  }

  private treeShadow(c: CanvasRenderingContext2D, x: number, baseY: number, s: number): void {
    c.fillStyle = 'rgba(20,60,40,0.18)'
    c.beginPath()
    c.ellipse(x + 3 * s, baseY + 2, 12 * s, 3.4 * s, 0, 0, Math.PI * 2)
    c.fill()
  }

  private tree(c: CanvasRenderingContext2D, x: number, baseY: number, s: number,
    skin: StageSkin, t: number, sway: number): void {
    this.treeShadow(c, x, baseY, s)
    c.fillStyle = '#8B5E3C'
    c.fillRect(x - 2.5 * s, baseY - 14 * s, 5 * s, 14 * s)
    c.fillStyle = skin.canopy
    c.beginPath()
    c.arc(x - 7 * s + sway, baseY - 18 * s, 9 * s, 0, Math.PI * 2)
    c.arc(x + 7 * s + sway, baseY - 18 * s, 9 * s, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = skin.canopyDeep
    c.beginPath()
    c.arc(x + sway, baseY - 24 * s, 10 * s, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = 'rgba(255,255,255,0.35)'
    c.beginPath()
    c.arc(x - 4 * s + sway, baseY - 26 * s, 2.2 * s, 0, Math.PI * 2)
    c.arc(x + 5 * s + sway, baseY - 21 * s, 1.8 * s, 0, Math.PI * 2)
    c.fill()
  }

  private deadTree(c: CanvasRenderingContext2D, x: number, baseY: number, s: number, t: number): void {
    this.treeShadow(c, x, baseY, s)
    c.strokeStyle = '#756D5E'
    c.lineWidth = 2.6 * s
    c.beginPath()
    c.moveTo(x, baseY)
    c.lineTo(x, baseY - 15 * s)
    c.moveTo(x, baseY - 10 * s)
    c.lineTo(x - 9 * s, baseY - 20 * s)
    c.moveTo(x, baseY - 12 * s)
    c.lineTo(x + 8 * s, baseY - 24 * s)
    c.moveTo(x - 5 * s, baseY - 16 * s)
    c.lineTo(x - 9 * s, baseY - 13 * s)
    c.stroke()
    // 乌鸦栖息在枯树顶(偶尔转头)
    const bob: number = Math.sin(t * 0.9) * 1.2
    c.fillStyle = '#1E1E22'
    c.beginPath()
    c.ellipse(x + 2 * s + bob, baseY - 30 * s, 5 * s, 3.6 * s, -0.2, 0, Math.PI * 2)
    c.fill()
    c.beginPath()
    c.arc(x + 6 * s + bob, baseY - 34 * s, 2.6 * s, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = '#E8B84B'
    c.beginPath()
    c.moveTo(x + 8 * s + bob, baseY - 34 * s)
    c.lineTo(x + 11 * s + bob, baseY - 33 * s)
    c.lineTo(x + 8 * s + bob, baseY - 32.4 * s)
    c.fill()
  }

  private conifer(c: CanvasRenderingContext2D, x: number, baseY: number, s: number,
    skin: StageSkin, t: number, sway: number): void {
    this.treeShadow(c, x, baseY, s)
    c.fillStyle = '#7A5236'
    c.fillRect(x - 2 * s, baseY - 10 * s, 4 * s, 10 * s)
    c.fillStyle = skin.canopyDeep
    for (let k = 0; k < 3; k++) {
      const wTri: number = (15 - k * 3.4) * s
      const yTop: number = baseY - (12 + k * 9) * s
      c.beginPath()
      c.moveTo(x - wTri, yTop + 11 * s)
      c.lineTo(x + sway * 0.4, yTop)
      c.lineTo(x + wTri, yTop + 11 * s)
      c.closePath()
      c.fill()
    }
  }

  private bush(c: CanvasRenderingContext2D, x: number, y: number, s: number, color: string): void {
    c.fillStyle = color
    c.beginPath()
    c.ellipse(x, y, 12 * s, 7.5 * s, 0, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = 'rgba(255,255,255,0.22)'
    c.beginPath()
    c.ellipse(x - 3 * s, y - 2.5 * s, 4.5 * s, 2.4 * s, 0, 0, Math.PI * 2)
    c.fill()
  }

  // ================= 阶段专属元素(灰屿 / 青屿 / 绿屿)=================

  /** 低空雾带(灰屿冷雾 / 青屿晨霭):缓慢横向漂移,两端渐隐 */
  private mistBand(c: CanvasRenderingContext2D, w: number, y: number, h: number,
    t: number, speed: number, alpha: number, rgb: string): void {
    const rad: number = w * 0.34
    const x0: number = ((t * speed) % (w * 1.7)) - w * 0.35
    const g = c.createLinearGradient(x0 - rad, 0, x0 + rad, 0)
    g.addColorStop(0, `rgba(${rgb},0)`)
    g.addColorStop(0.5, `rgba(${rgb},${alpha})`)
    g.addColorStop(1, `rgba(${rgb},0)`)
    c.fillStyle = g
    c.beginPath()
    c.ellipse(x0, y + Math.sin(t * 0.6) * 3, rad, h * 0.026, 0, 0, Math.PI * 2)
    c.fill()
  }

  /** 盘旋鸦群(灰屿):三只乌鸦沿椭圆航线绕飞,随飞行扇翅 */
  private crows(c: CanvasRenderingContext2D, w: number, h: number, t: number): void {
    for (let i = 0; i < 3; i++) {
      const ph: number = t * 0.42 + i * 2.1
      const cx: number = w * 0.36 + Math.cos(ph) * w * 0.15
      const cy: number = h * 0.155 + Math.sin(ph) * h * 0.042 - i * 7
      const flap: number = Math.sin(t * 6.2 + i * 1.5) * 3.6
      const sp: number = 1 - i * 0.12
      c.strokeStyle = `rgba(28,30,36,${0.82 - i * 0.14})`
      c.lineWidth = 2.1 * sp
      c.beginPath()
      c.moveTo(cx - 9 * sp, cy + 1)
      c.quadraticCurveTo(cx - 3 * sp, cy - 5 - flap, cx, cy)
      c.quadraticCurveTo(cx + 3 * sp, cy - 5 - flap, cx + 9 * sp, cy + 1)
      c.stroke()
      c.fillStyle = `rgba(28,30,36,${0.72 - i * 0.14})`
      c.beginPath()
      c.ellipse(cx, cy + 1.4, 3 * sp, 1.9 * sp, 0, 0, Math.PI * 2)
      c.fill()
    }
  }

  /** 远海地平线冷光(灰屿):海平线上的冷色微光,缓慢明暗呼吸 */
  private horizonGlow(c: CanvasRenderingContext2D, w: number, h: number, t: number, seaY: number): void {
    const a: number = 0.14 + 0.10 * (0.5 + 0.5 * Math.sin(t * 0.5))
    const g = c.createLinearGradient(0, seaY - h * 0.07, 0, seaY + h * 0.06)
    g.addColorStop(0, 'rgba(186,208,218,0)')
    g.addColorStop(0.52, `rgba(186,208,218,${a})`)
    g.addColorStop(1, 'rgba(150,178,192,0)')
    c.fillStyle = g
    c.fillRect(0, seaY - h * 0.07, w, h * 0.13)
  }

  /** 破晓光束(青屿):自日出方向斜射的柔光,缓慢摇曳 */
  private dawnRays(c: CanvasRenderingContext2D, h: number, t: number, sx: number, sy: number): void {
    const len: number = h * 0.98
    for (let i = 0; i < 4; i++) {
      const sway: number = Math.sin(t * 0.45 + i * 0.9) * 0.07
      const a0: number = 1.84 + i * 0.17 + sway
      const a1: number = a0 + 0.095
      const glow: number = 0.085 + 0.075 * (0.5 + 0.5 * Math.sin(t * 0.7 + i * 1.4))
      c.fillStyle = `rgba(255,238,198,${glow})`
      c.beginPath()
      c.moveTo(sx, sy)
      c.lineTo(sx + Math.cos(a0) * len, sy + Math.sin(a0) * len)
      c.lineTo(sx + Math.cos(a1) * len, sy + Math.sin(a1) * len)
      c.closePath()
      c.fill()
    }
  }

  /** 海面日影光柱(青屿/绿屿):太阳在水面的倒影带与粼光 */
  private sunGlitter(c: CanvasRenderingContext2D, h: number, seaY: number,
    t: number, sx: number, rgb: string): void {
    c.fillStyle = `rgba(${rgb},0.22)`
    c.beginPath()
    c.moveTo(sx - 10, seaY)
    c.lineTo(sx + 10, seaY)
    c.lineTo(sx + 32, h)
    c.lineTo(sx - 32, h)
    c.closePath()
    c.fill()
    for (let i = 0; i < 6; i++) {
      const yy: number = seaY + 16 + i * h * 0.055
      const wob: number = Math.sin(t * 1.5 + i * 1.3) * 15
      const a: number = 0.30 + 0.34 * (0.5 + 0.5 * Math.sin(t * 2.1 + i * 1.1))
      c.fillStyle = `rgba(${rgb},${a})`
      c.fillRect(sx + wob - 13, yy, 26 - (i % 3) * 6, 2.2)
    }
  }

  /** 希望之芽(灰屿):荒原上第一株嫩芽,带微弱呼吸绿光(进化的第一个信号) */
  private hopeSprout(c: CanvasRenderingContext2D, x: number, baseY: number, t: number): void {
    const pulse: number = 0.5 + 0.5 * Math.sin(t * 1.5)
    c.fillStyle = `rgba(124,205,150,${0.08 + 0.10 * pulse})`
    c.beginPath()
    c.arc(x, baseY - 9, 12 + pulse * 4, 0, Math.PI * 2)
    c.fill()
    c.strokeStyle = '#86BE94'
    c.lineWidth = 1.7
    c.beginPath()
    c.moveTo(x, baseY)
    c.quadraticCurveTo(x + 1.6, baseY - 6, x, baseY - 10)
    c.stroke()
    c.fillStyle = '#8FCB88'
    c.beginPath()
    c.ellipse(x - 4.2, baseY - 9.5, 4.6, 2.5, -0.55 + pulse * 0.1, 0, Math.PI * 2)
    c.ellipse(x + 4.2, baseY - 10.5, 4.6, 2.5, 0.55 - pulse * 0.1, 0, Math.PI * 2)
    c.fill()
  }

  /** 嫩芽(青屿):岛上冒头的双叶幼苗,随风轻摆 */
  private sprout(c: CanvasRenderingContext2D, x: number, baseY: number, t: number, s: number): void {
    const sway: number = Math.sin(t * 1.7 + x * 0.05) * 0.9
    c.strokeStyle = '#6FAE7E'
    c.lineWidth = 1.6 * s
    c.beginPath()
    c.moveTo(x, baseY)
    c.quadraticCurveTo(x + s + sway, baseY - 4 * s, x + sway, baseY - 7.5 * s)
    c.stroke()
    c.fillStyle = '#9ED18C'
    c.beginPath()
    c.ellipse(x - 3.2 * s + sway, baseY - 7 * s, 3.6 * s, 2.1 * s, -0.5, 0, Math.PI * 2)
    c.ellipse(x + 3.2 * s + sway, baseY - 8 * s, 3.6 * s, 2.1 * s, 0.5, 0, Math.PI * 2)
    c.fill()
  }

  /** 岸边浪花(绿屿):拍岸白沫,呼吸式扩散 */
  private shoreFoam(c: CanvasRenderingContext2D, cx: number, baseY: number, w: number, t: number): void {
    for (let i = 0; i < 5; i++) {
      const ph: number = (t * 0.45 + i * 0.21) % 1
      const a: number = Math.sin(ph * Math.PI) * 0.5
      const fx0: number = cx + w * (-0.40 + 0.20 * i)
      const fy0: number = baseY + 13 + Math.sin(i * 2.1) * 3
      c.strokeStyle = `rgba(255,255,255,${a})`
      c.lineWidth = 2.4
      c.beginPath()
      c.moveTo(fx0 - 13 - ph * 12, fy0)
      c.quadraticCurveTo(fx0, fy0 - 5 - ph * 4, fx0 + 13 + ph * 12, fy0)
      c.stroke()
    }
  }

  /** 系泊小船(绿屿):码头旁随波轻晃的小船 */
  private mooredBoat(c: CanvasRenderingContext2D, x: number, y: number, t: number): void {
    const tilt: number = Math.sin(t * 1.25) * 1.1
    const yy: number = y + Math.sin(t * 1.25 + 0.6) * 1.6
    c.fillStyle = 'rgba(20,60,50,0.16)'
    c.beginPath()
    c.ellipse(x, yy + 6, 15, 3, 0, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = '#F2EBDD'
    c.beginPath()
    c.moveTo(x - 14, yy + tilt)
    c.lineTo(x + 14, yy - tilt)
    c.lineTo(x + 8.5, yy + 6.5 - tilt)
    c.lineTo(x - 8.5, yy + 6.5 + tilt)
    c.closePath()
    c.fill()
    c.fillStyle = '#C7B092'
    c.beginPath()
    c.moveTo(x - 14, yy + tilt)
    c.lineTo(x + 14, yy - tilt)
    c.lineTo(x + 14, yy + 1.6 - tilt)
    c.lineTo(x - 14, yy + 1.6 + tilt)
    c.closePath()
    c.fill()
    c.strokeStyle = '#8B5E3C'
    c.lineWidth = 1.6
    c.beginPath()
    c.moveTo(x, yy - tilt * 0.2)
    c.lineTo(x, yy - 15 - tilt * 0.2)
    c.stroke()
    c.fillStyle = '#D96C5F'
    c.beginPath()
    c.moveTo(x, yy - 15 - tilt * 0.2)
    c.lineTo(x + 9 + Math.sin(t * 2.2) * 1.6, yy - 11.5 - tilt * 0.2)
    c.lineTo(x, yy - 8 - tilt * 0.2)
    c.closePath()
    c.fill()
  }

  /** 风中枯叶(灰屿):几片卷曲落叶随风飘过 */
  private deadLeaves(c: CanvasRenderingContext2D, w: number, h: number, t: number): void {
    for (let i = 0; i < 4; i++) {
      const x: number = ((t * (24 + i * 9)) % (w + 100)) - 50
      const y: number = h * (0.30 + (i % 3) * 0.075) + Math.sin(t * 1.3 + i * 1.9) * 10
      const spin: number = Math.sin(t * 2.6 + i) * 0.7
      c.fillStyle = `rgba(152,138,116,${0.62 - i * 0.09})`
      c.beginPath()
      c.ellipse(x, y, 4.4, 2.0, spin, 0, Math.PI * 2)
      c.fill()
    }
  }

  /** 晨光微尘(青屿):空气中缓慢上浮的光点 */
  private motes(c: CanvasRenderingContext2D, w: number, h: number, t: number): void {
    const baseY: number = h * 0.50
    const rise: number = h * 0.36
    for (let i = 0; i < 9; i++) {
      const mx: number = w * (0.12 + 0.088 * i) + Math.sin(t * 0.45 + i * 1.7) * 15
      const my: number = baseY - ((t * (4 + i * 1.1) + i * 26) % rise)
      const a: number = 0.18 + 0.24 * (0.5 + 0.5 * Math.sin(t * 1.7 + i))
      c.fillStyle = `rgba(255,240,205,${a})`
      c.beginPath()
      c.arc(mx, my, 1.6 + (i % 3) * 0.5, 0, Math.PI * 2)
      c.fill()
    }
  }

  private draw(): void {
    const c = this.ctx
    const w: number = c.width
    const h: number = c.height
    const t: number = Date.now() / 1000
    this.pulseVal *= 0.94
    if (this.pulseVal < 0.01) {
      this.pulseVal = 0
    }
    const breath: number = 1 + Math.sin(t * Math.PI / 2) * 0.012
    const st: number = this.stage
    const isBare: boolean = st === 0
    const isDawn: boolean = st === 1
    const skin: StageSkin = SKINS[Math.min(4, Math.max(0, st))]
    c.clearRect(0, 0, w, h)

    // ===== 天空(每阶段不同天光)=====
    const grad = c.createLinearGradient(0, 0, 0, h * 0.9)
    grad.addColorStop(0, skin.skyTop)
    grad.addColorStop(1, skin.skyBottom)
    c.fillStyle = grad
    c.fillRect(0, 0, w, h)

    // 太阳(各阶段位置/颜色/大小不同:s3 是沉向海平线的橙色夕阳)
    if (skin.sunVisible) {
      const sy: number = h * skin.sunY
      c.fillStyle = 'rgba(255,214,110,0.18)'
      c.beginPath()
      c.arc(w * 0.80, sy, skin.sunR * 2, 0, Math.PI * 2)
      c.fill()
      c.fillStyle = skin.sunColor
      c.beginPath()
      c.arc(w * 0.80, sy, skin.sunR, 0, Math.PI * 2)
      c.fill()
    }

    // 青屿破晓:自日出方向斜射的丁达尔光束(缓慢摇曳)
    if (isDawn) {
      this.dawnRays(c, h, t, w * 0.80, h * skin.sunY)
    }

    // 彩虹(生态屿)
    if (st >= 4) {
      const rcolors: string[] = ['rgba(240,110,100,0.30)', 'rgba(250,190,80,0.28)', 'rgba(110,200,140,0.26)', 'rgba(100,160,230,0.26)']
      for (let i = 0; i < 4; i++) {
        c.beginPath()
        c.strokeStyle = rcolors[i]
        c.lineWidth = 5
        c.arc(w * 0.5, h * 0.78, w * 0.44 - i * 6, Math.PI, Math.PI * 2)
        c.stroke()
      }
    }

    // 云(s0 灰云,s2+ 白云)
    this.cloud(c, ((t * 12) % (w + 120)) - 60, h * 0.12, 1.0, 0.8, st === 0)
    this.cloud(c, w - ((t * 8) % (w + 140)) + 40, h * 0.22, 0.7, 0.55, st === 0)
    if (st >= 2) {
      this.cloud(c, ((t * 6 + 300) % (w + 100)) - 50, h * 0.045, 0.55, 0.5, false)
    }

    // 灰屿:低空冷雾带(漂移的湿冷雾气)+ 盘旋鸦群
    if (isBare) {
      this.mistBand(c, w, h * 0.40, h, t, 9, 0.30, '226,232,236')
      this.mistBand(c, w, h * 0.455, h, t, 5.5, 0.20, '210,220,228')
      this.crows(c, w, h, t)
    }
    // 青屿:海面暖调晨霭
    if (isDawn) {
      this.mistBand(c, w, h * 0.475, h, t, 6.5, 0.22, '255,238,214')
    }

    // 海鸟(灰屿无鸟,唯乌鸦;绿屿起鸟群更近更大)
    if (st >= 1) {
      const birdN: number = st >= 2 ? 3 : 2
      c.strokeStyle = st >= 2 ? 'rgba(36,72,62,0.80)' : 'rgba(40,70,64,0.70)'
      c.lineWidth = st >= 2 ? 2.6 : 2.2
      for (let b = 0; b < birdN; b++) {
        const bx: number = ((t * (30 + b * 10)) % (w + 80)) - 40
        const by: number = h * (0.18 + b * 0.06) + Math.sin(t * 1.3 + b) * 8
        const flap: number = Math.sin(t * 7 + b * 2) * 3
        const bs: number = st >= 2 ? 1.25 : 1
        c.beginPath()
        c.moveTo(bx - 8 * bs, by)
        c.quadraticCurveTo(bx - 3 * bs, by - (5 + flap) * bs, bx, by)
        c.quadraticCurveTo(bx + 3 * bs, by - (5 + flap) * bs, bx + 8 * bs, by)
        c.stroke()
      }
    }

    // ===== 海(每阶段海色)=====
    const seaY: number = h * 0.50
    const seaGrad = c.createLinearGradient(0, seaY, 0, h)
    seaGrad.addColorStop(0, skin.seaTop)
    seaGrad.addColorStop(1, skin.sea)
    c.fillStyle = seaGrad
    c.fillRect(0, seaY, w, h - seaY)

    // 灰屿:远海地平线冷光(缓慢明暗呼吸)
    if (isBare) {
      this.horizonGlow(c, w, h, t, seaY)
    }
    // 青屿/绿屿:太阳在海面的倒影光柱与粼光
    if (st === 1) {
      this.sunGlitter(c, h, seaY, t, w * 0.80, '255,240,205')
    } else if (st === 2) {
      this.sunGlitter(c, h, seaY, t, w * 0.80, '255,252,238')
    }

    // 倒影
    c.fillStyle = 'rgba(60,110,95,0.12)'
    c.beginPath()
    c.ellipse(w * 0.5, seaY + h * 0.14, w * 0.36 * breath, h * 0.10, 0, 0, Math.PI * 2)
    c.fill()

    // 浪线
    c.strokeStyle = 'rgba(255,255,255,0.45)'
    c.lineWidth = 2
    for (let k = 0; k < 3; k++) {
      c.beginPath()
      const yy: number = seaY + 16 + k * 18
      for (let x = 0; x <= w; x += 12) {
        const y: number = yy + Math.sin(x / 34 + t * 1.6 + k * 1.8) * 3
        if (x === 0) {
          c.moveTo(x, y)
        } else {
          c.lineTo(x, y)
        }
      }
      c.stroke()
    }

    // 帆船(绿屿+)
    if (st >= 2) {
      const fx: number = ((t * 10) % (w + 160)) - 80
      const fy: number = seaY + 20 + Math.sin(t * 1.1) * 2.5
      // 尾迹(船后拖出的水痕)
      c.strokeStyle = 'rgba(255,255,255,0.55)'
      c.lineWidth = 1.8
      for (let k = 0; k < 2; k++) {
        c.beginPath()
        c.moveTo(fx - 13 - k * 7, fy + 5 + k * 2)
        c.quadraticCurveTo(fx - 23 - k * 10, fy + 6 + k * 3, fx - 34 - k * 12, fy + 4 + k * 4.5)
        c.stroke()
      }
      c.fillStyle = '#FFFFFF'
      c.beginPath()
      c.moveTo(fx, fy - 15)
      c.quadraticCurveTo(fx + 9, fy - 8, fx + 7, fy)
      c.closePath()
      c.fill()
      c.fillStyle = '#D96C5F'
      c.beginPath()
      c.moveTo(fx - 10, fy + 3)
      c.lineTo(fx + 10, fy + 3)
      c.lineTo(fx + 7, fy + 8)
      c.lineTo(fx - 7, fy + 8)
      c.closePath()
      c.fill()
    }

    // 鲸背喷水(生态屿)
    if (st >= 4) {
      const wx: number = w * 0.2
      const wy: number = seaY + h * 0.16 + Math.sin(t * 0.8) * 3
      c.fillStyle = '#2E4A5E'
      c.beginPath()
      c.ellipse(wx, wy, 24, 8, -0.12, Math.PI, Math.PI * 2)
      c.fill()
      if (Math.sin(t * 1.4) > 0.3) {
        c.fillStyle = 'rgba(255,255,255,0.75)'
        for (let i = 0; i < 4; i++) {
          c.beginPath()
          c.arc(wx + 4 - i * 3, wy - 12 - i * 6, 2.6 - i * 0.4, 0, Math.PI * 2)
          c.fill()
        }
      }
    }

    // ===== 岛 =====
    const islandCx: number = w * 0.5
    const islandBase: number = seaY + h * 0.045
    c.fillStyle = skin.canopyDeep
    c.globalAlpha = 0.45
    c.beginPath()
    c.ellipse(islandCx - w * 0.12, islandBase - h * 0.025, w * 0.33 * breath, h * 0.19 * breath, 0, Math.PI, Math.PI * 2)
    c.fill()
    c.globalAlpha = 1
    const isleGrad = c.createLinearGradient(0, islandBase - h * 0.22, 0, islandBase + 12)
    isleGrad.addColorStop(0, skin.islandLight)
    isleGrad.addColorStop(0.55, skin.island)
    isleGrad.addColorStop(1, skin.canopyDeep)
    c.fillStyle = isleGrad
    c.beginPath()
    c.ellipse(islandCx, islandBase + 6, w * 0.50 * breath, h * 0.27 * breath, 0, Math.PI, Math.PI * 2)
    c.fill()
    c.fillStyle = skin.island
    c.beginPath()
    c.ellipse(islandCx - w * 0.34, islandBase + 4, w * 0.075 * breath, h * 0.10 * breath, 0, Math.PI, Math.PI * 2)
    c.ellipse(islandCx + w * 0.33, islandBase + 4, w * 0.065 * breath, h * 0.09 * breath, 0, Math.PI, Math.PI * 2)
    c.fill()
    c.fillStyle = 'rgba(238,222,180,0.9)'
    c.beginPath()
    c.ellipse(islandCx, islandBase + 8, w * 0.48, h * 0.055, 0, 0, Math.PI * 2)
    c.fill()
    c.strokeStyle = 'rgba(255,255,255,0.55)'
    c.lineWidth = 2.4
    for (let k = 0; k < 2; k++) {
      c.beginPath()
      c.ellipse(islandCx, islandBase + 10 + k * 7, w * (0.49 + k * 0.025), h * (0.05 + k * 0.012), 0, 0.15, Math.PI - 0.15)
      c.stroke()
    }

    // 灰屿:裂痕 + 枯草
    if (isBare) {
      c.strokeStyle = 'rgba(90,84,70,0.5)'
      c.lineWidth = 1.6
      for (let i = 0; i < 3; i++) {
        const cx0: number = w * (0.34 + i * 0.14)
        const cy0: number = islandBase - h * (0.04 + i * 0.03)
        c.beginPath()
        c.moveTo(cx0, cy0)
        c.lineTo(cx0 + 9, cy0 - 5)
        c.lineTo(cx0 + 15, cy0 - 2)
        c.stroke()
      }
      c.strokeStyle = 'rgba(120,112,95,0.7)'
      for (let i = 0; i < 5; i++) {
        const gx: number = w * (0.30 + i * 0.09)
        const gy: number = islandBase - h * (0.02 + (i % 2) * 0.02)
        c.beginPath()
        c.moveTo(gx, gy)
        c.lineTo(gx - 2, gy - 6)
        c.moveTo(gx + 3, gy)
        c.lineTo(gx + 4, gy - 5)
        c.stroke()
      }
      // 荒原上第一株嫩芽:微弱的绿光,暗示进化即将开始
      this.hopeSprout(c, w * 0.645, islandBase - h * 0.012, t)
    }

    // 青屿破晓露珠(草尖亮点)
    if (isDawn) {
      c.fillStyle = 'rgba(255,255,255,0.9)'
      for (let i = 0; i < 6; i++) {
        const dx: number = w * (0.30 + 0.07 * i) + Math.sin(i * 4) * 12
        const dy: number = islandBase - h * (0.045 + (i % 3) * 0.035)
        c.beginPath()
        c.arc(dx, dy, 1.8, 0, Math.PI * 2)
        c.fill()
      }
      // 破土而出的嫩芽(随风轻摆)
      this.sprout(c, w * 0.36, islandBase - h * 0.018, t, 0.9)
      this.sprout(c, w * 0.575, islandBase - h * 0.010, t, 1.0)
      this.sprout(c, w * 0.725, islandBase - h * 0.020, t, 0.75)
    }

    // ===== 树(阔叶摇摆 + 森屿混种松杉 + 乌鸦)=====
    const n: number = skin.trees
    for (let i = 0; i < n; i++) {
      const slot: number[] = TREE_SLOTS[i]
      const x: number = w * (0.5 + (slot[0] - 0.5) * 0.96)
      const baseY: number = islandBase - h * 0.04 - slot[1] * h * 0.36
      const s: number = (1.0 + slot[1] * 0.8) * (1 + this.pulseVal * 0.32)
      const sway: number = Math.sin(t * 1.6 + slot[0] * 9) * 2.2 * s
      if (st === 0 && i === 0) {
        this.deadTree(c, x, baseY, s, t)
      } else if (st >= 3 && i % 2 === 1) {
        this.conifer(c, x, baseY, s, skin, t, sway)
      } else {
        this.tree(c, x, baseY, s, skin, t, sway)
      }
      if (st >= 2 && !useConiferFlag(st, i) && i % 2 === 0) {
        c.fillStyle = '#F2A65A'
        c.beginPath()
        c.arc(x - 5 * s + sway, baseY - 20 * s, 1.8 * s, 0, Math.PI * 2)
        c.arc(x + 6 * s + sway, baseY - 16 * s, 1.8 * s, 0, Math.PI * 2)
        c.fill()
      }
    }
    // 灌木(青屿+)
    if (st >= 1) {
      this.bush(c, w * 0.33, islandBase - h * 0.012, 1.0, skin.canopy)
      this.bush(c, w * 0.52, islandBase - h * 0.008, 0.85, skin.canopy)
      this.bush(c, w * 0.68, islandBase - h * 0.014, 0.9, skin.canopy)
    }

    // 码头(绿屿+)
    if (st >= 2) {
      const dx: number = w * 0.74
      c.fillStyle = '#A0714B'
      c.fillRect(dx, islandBase + h * 0.025, w * 0.11, 5)
      c.fillStyle = '#8B5E3C'
      for (let i = 0; i < 3; i++) {
        c.fillRect(dx + 8 + i * (w * 0.11 - 16) / 2, islandBase + h * 0.025 + 5, 3, 11)
      }
    }

    // 绿屿:码头旁系泊的小船 + 系缆 + 岸边浪花
    if (st === 2) {
      const bx: number = w * 0.885
      const by: number = islandBase + h * 0.058
      c.strokeStyle = 'rgba(120,96,72,0.75)'
      c.lineWidth = 1.4
      c.beginPath()
      c.moveTo(w * 0.845, islandBase + h * 0.030)
      c.quadraticCurveTo(w * 0.87, islandBase + h * 0.048, bx - 11, by + 2)
      c.stroke()
      this.mooredBoat(c, bx, by, t)
      this.shoreFoam(c, islandCx, islandBase, w, t)
    }

    // 瀑布(生态屿:悬崖飞瀑)
    if (st >= 4) {
      const fx0: number = w * 0.615
      const fy0: number = islandBase - h * 0.055
      const fw: number = 14
      c.fillStyle = 'rgba(235,252,255,0.9)'
      c.beginPath()
      c.moveTo(fx0, fy0)
      for (let yy = 0; yy <= h * 0.14; yy += 6) {
        c.lineTo(fx0 + fw + Math.sin(yy / 9 + t * 3) * 2.5, fy0 + yy)
      }
      for (let yy = h * 0.14; yy >= 0; yy -= 6) {
        c.lineTo(fx0 + fw + Math.sin(yy / 9 + t * 3) * 2.5 - fw, fy0 + yy)
      }
      c.closePath()
      c.fill()
      c.fillStyle = 'rgba(255,255,255,0.8)'
      c.beginPath()
      c.ellipse(fx0 + fw / 2, fy0 + h * 0.145, fw * 0.9, 4, 0, 0, Math.PI * 2)
      c.fill()
    }

    // 风车(森屿+)
    if (st >= 3) {
      const wx: number = w * 0.74
      const wBase: number = islandBase - h * 0.09
      c.fillStyle = '#E8E2D4'
      c.fillRect(wx - 3.5, wBase - 52, 7, 52)
      const ang: number = t * 2.2
      c.strokeStyle = '#F7F5EE'
      c.lineWidth = 4.5
      for (let b = 0; b < 3; b++) {
        const a: number = ang + b * Math.PI * 2 / 3
        c.beginPath()
        c.moveTo(wx, wBase - 52)
        c.lineTo(wx + Math.cos(a) * 26, wBase - 52 + Math.sin(a) * 26)
        c.stroke()
      }
      c.fillStyle = '#D96C5F'
      c.beginPath()
      c.arc(wx, wBase - 52, 4.5, 0, Math.PI * 2)
      c.fill()
    }

    // 海面光斑(绿屿+)
    if (st >= 2) {
      c.fillStyle = 'rgba(255,255,255,0.5)'
      for (let i = 0; i < 5; i++) {
        const sx: number = w * (0.08 + 0.19 * i) + Math.sin(t + i) * 8
        const sy: number = seaY + h * (0.12 + (i % 3) * 0.07)
        c.fillRect(sx, sy, 15 - (i % 3) * 3, 2)
      }
    }

    // 鱼跃(绿屿+)
    if (st >= 2) {
      const fishCycle: number = t % 7
      if (fishCycle > 5.6 && fishCycle < 6.4) {
        const fp: number = (fishCycle - 5.6) / 0.8
        const jx: number = w * 0.18
        const jy: number = seaY + h * 0.20 - Math.sin(fp * Math.PI) * 26
        c.fillStyle = '#4E8FB8'
        c.beginPath()
        c.ellipse(jx, jy, 7, 3, -0.5 + fp * 1.2, 0, Math.PI * 2)
        c.fill()
        c.fillStyle = 'rgba(255,255,255,0.7)'
        c.beginPath()
        c.arc(jx - 6, seaY + h * 0.20, 3 + fp * 3, 0, Math.PI * 2)
        c.fill()
      }
    }

    // 萤火虫(森屿+)
    if (st >= 3) {
      for (let i = 0; i < 4; i++) {
        const fx2: number = w * (0.16 + 0.22 * i) + Math.sin(t * (0.8 + i * 0.3) + i * 2) * 38
        const fy2: number = islandBase - h * (0.10 + (i % 2) * 0.08) + Math.cos(t * (0.6 + i * 0.2) + i) * 22
        const glow: number = 0.35 + 0.3 * (0.5 + 0.5 * Math.sin(t * 2.2 + i * 1.7))
        c.fillStyle = `rgba(251,191,36,${glow})`
        c.beginPath()
        c.arc(fx2, fy2, 3.2, 0, Math.PI * 2)
        c.fill()
        c.fillStyle = `rgba(251,191,36,${glow * 0.25})`
        c.beginPath()
        c.arc(fx2, fy2, 8, 0, Math.PI * 2)
        c.fill()
      }
    }

    // 蝴蝶(生态屿)
    if (st >= 4) {
      for (let i = 0; i < 3; i++) {
        const bx: number = w * (0.3 + 0.2 * i) + Math.sin(t * 1.4 + i * 2) * 26
        const by: number = islandBase - h * 0.13 - Math.abs(Math.sin(t * 1.1 + i)) * 30
        const wing: number = 3 + Math.sin(t * 9 + i) * 1.6
        c.fillStyle = ['#F2A65A', '#C583D6', '#F2708A'][i]
        c.beginPath()
        c.ellipse(bx - wing, by, wing, 2.4, 0.6, 0, Math.PI * 2)
        c.ellipse(bx + wing, by, wing, 2.4, -0.6, 0, Math.PI * 2)
        c.fill()
      }
    }

    // ===== 前景氛围层(贴地雾 / 飘叶 / 光尘,拉开前后景层次)=====
    // 灰屿:贴地冷雾 + 风中飘散的枯叶
    if (isBare) {
      this.mistBand(c, w, h * 0.487, h, t, 7, 0.18, '226,232,236')
      this.deadLeaves(c, w, h, t)
    }
    // 青屿:贴地晨霭 + 晨曦里上浮的光尘
    if (isDawn) {
      this.mistBand(c, w, h * 0.492, h, t, 5, 0.16, '255,238,214')
      this.motes(c, w, h, t)
    }

    // ===== 阶段色彩分级(全屏情绪滤镜)=====
    c.fillStyle = skin.grade
    c.fillRect(0, 0, w, h)
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
  }
}

function useConiferFlag(stage: number, i: number): boolean {
  return stage >= 3 && i % 2 === 1
}
