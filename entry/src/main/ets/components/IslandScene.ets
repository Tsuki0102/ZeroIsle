import { ZeroTheme } from '../common/Theme'

/**
 * 岛屿场景 v4:首页主视觉(全屏 Canvas)
 * 构图:天空(云/日/鸟) → 大岛(后山/主丘渐变/树/灌木/风车/码头) → 海(渐变/浪/帆船/鱼跃/光斑)
 * 阶段进化:0灰屿 1青屿 2绿屿 3森屿 4生态屿;含呼吸/生长脉冲/海鸟/萤火虫/蝴蝶/彩虹
 */
interface StageSkin {
  skyTop: string
  skyBottom: string
  sea: string
  island: string
  islandLight: string
  canopy: string
  canopyDeep: string
  trees: number
}

const SKINS: StageSkin[] = [
  { skyTop: '#C9CFCC', skyBottom: '#EDEFEA', sea: '#B7D6D6', island: '#A89F8D', islandLight: '#C4BCAA', canopy: '#8A8378', canopyDeep: '#6E675C', trees: 1 },
  { skyTop: '#D8EEF3', skyBottom: '#F6F3E7', sea: '#A8D8DA', island: '#79B473', islandLight: '#A5D6A7', canopy: '#4F9D69', canopyDeep: '#3B7D54', trees: 2 },
  { skyTop: '#DFF3F1', skyBottom: '#FDF6EC', sea: '#9ED8DB', island: '#5B9E63', islandLight: '#8FCB88', canopy: '#2E7D5B', canopyDeep: '#1F5A40', trees: 4 },
  { skyTop: '#D5F0EC', skyBottom: '#FCF3E3', sea: '#8FCFD2', island: '#3E7C50', islandLight: '#6FAF7E', canopy: '#1F5A40', canopyDeep: '#15432F', trees: 7 },
  { skyTop: '#D9F2EF', skyBottom: '#FFF4DE', sea: '#7FC5C9', island: '#2E6B4F', islandLight: '#5FA38A', canopy: '#175038', canopyDeep: '#0F3D2B', trees: 10 }
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
  private pulseVal: number = 0

  onGrow(): void {
    this.pulseVal = 1
  }

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      this.draw()
    }, 80)
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer)
    }
  }

  redraw() {
    this.draw()
  }

  private cloud(c: CanvasRenderingContext2D, x: number, y: number, s: number, alpha: number): void {
    c.fillStyle = `rgba(255,255,255,${alpha})`
    c.beginPath()
    c.arc(x, y, 18 * s, 0, Math.PI * 2)
    c.arc(x + 22 * s, y - 8 * s, 22 * s, 0, Math.PI * 2)
    c.arc(x + 46 * s, y, 16 * s, 0, Math.PI * 2)
    c.fill()
  }

  private tree(c: CanvasRenderingContext2D, x: number, baseY: number, s: number, skin: StageSkin, dead: boolean): void {
    c.fillStyle = 'rgba(20,60,40,0.18)'
    c.beginPath()
    c.ellipse(x + 3 * s, baseY + 2, 12 * s, 3.4 * s, 0, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = '#8B5E3C'
    c.fillRect(x - 2.5 * s, baseY - 14 * s, 5 * s, 14 * s)
    if (dead) {
      c.strokeStyle = '#8A8378'
      c.lineWidth = 2
      c.beginPath()
      c.moveTo(x, baseY - 12 * s)
      c.lineTo(x - 8 * s, baseY - 22 * s)
      c.moveTo(x, baseY - 12 * s)
      c.lineTo(x + 7 * s, baseY - 24 * s)
      c.stroke()
      return
    }
    c.fillStyle = skin.canopy
    c.beginPath()
    c.arc(x - 7 * s, baseY - 18 * s, 9 * s, 0, Math.PI * 2)
    c.arc(x + 7 * s, baseY - 18 * s, 9 * s, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = skin.canopyDeep
    c.beginPath()
    c.arc(x, baseY - 24 * s, 10 * s, 0, Math.PI * 2)
    c.fill()
    c.fillStyle = 'rgba(255,255,255,0.35)'
    c.beginPath()
    c.arc(x - 4 * s, baseY - 26 * s, 2.2 * s, 0, Math.PI * 2)
    c.arc(x + 5 * s, baseY - 21 * s, 1.8 * s, 0, Math.PI * 2)
    c.fill()
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
    const skin: StageSkin = SKINS[Math.min(4, Math.max(0, this.stage))]
    c.clearRect(0, 0, w, h)

    // ===== 天空 =====
    const grad = c.createLinearGradient(0, 0, 0, h)
    grad.addColorStop(0, skin.skyTop)
    grad.addColorStop(1, skin.skyBottom)
    c.fillStyle = grad
    c.fillRect(0, 0, w, h)

    // 太阳(双层光晕)
    if (this.stage >= 1) {
      c.fillStyle = 'rgba(255,214,110,0.22)'
      c.beginPath()
      c.arc(w * 0.80, h * 0.13, 34, 0, Math.PI * 2)
      c.fill()
      c.fillStyle = this.stage >= 4 ? 'rgba(255,196,80,0.95)' : 'rgba(255,214,110,0.9)'
      c.beginPath()
      c.arc(w * 0.80, h * 0.13, 18, 0, Math.PI * 2)
      c.fill()
    }

    // 彩虹(生态屿)
    if (this.stage >= 4) {
      const rcolors: string[] = ['rgba(240,110,100,0.32)', 'rgba(250,190,80,0.30)', 'rgba(110,200,140,0.28)', 'rgba(100,160,230,0.28)']
      for (let i = 0; i < 4; i++) {
        c.beginPath()
        c.strokeStyle = rcolors[i]
        c.lineWidth = 5
        c.arc(w * 0.5, h * 0.80, w * 0.44 - i * 6, Math.PI, Math.PI * 2)
        c.stroke()
      }
    }

    // 云 ×3
    this.cloud(c, ((t * 12) % (w + 120)) - 60, h * 0.12, 1.0, 0.85)
    this.cloud(c, w - ((t * 8) % (w + 140)) + 40, h * 0.22, 0.7, 0.6)
    this.cloud(c, ((t * 6 + 300) % (w + 100)) - 50, h * 0.045, 0.55, 0.5)

    // 海鸟 ×2
    c.strokeStyle = 'rgba(40,70,64,0.7)'
    c.lineWidth = 2.2
    for (let b = 0; b < 2; b++) {
      const bx: number = ((t * (30 + b * 10)) % (w + 80)) - 40
      const by: number = h * (0.20 + b * 0.06) + Math.sin(t * 1.3 + b) * 8
      const flap: number = Math.sin(t * 7 + b * 2) * 3
      c.beginPath()
      c.moveTo(bx - 8, by)
      c.quadraticCurveTo(bx - 3, by - 5 - flap, bx, by)
      c.quadraticCurveTo(bx + 3, by - 5 - flap, bx + 8, by)
      c.stroke()
    }

    // ===== 海(纵向渐变)=====
    const seaY: number = h * 0.52
    const seaGrad = c.createLinearGradient(0, seaY, 0, h)
    seaGrad.addColorStop(0, '#C2E8EA')
    seaGrad.addColorStop(1, skin.sea)
    c.fillStyle = seaGrad
    c.fillRect(0, seaY, w, h - seaY)
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

    // 远景小帆船(缓慢横移)
    const fx: number = ((t * 10) % (w + 160)) - 80
    const fy: number = seaY + 22 + Math.sin(t * 1.1) * 2.5
    c.fillStyle = '#FFFFFF'
    c.beginPath()
    c.moveTo(fx, fy - 16)
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

    // ===== 岛(后山 → 主丘渐变 → 岛滩)=====
    const islandCx: number = w * 0.5
    const islandBase: number = seaY + h * 0.05
    c.fillStyle = skin.canopyDeep
    c.globalAlpha = 0.45
    c.beginPath()
    c.ellipse(islandCx - w * 0.11, islandBase - h * 0.02, w * 0.30 * breath, h * 0.17 * breath, 0, Math.PI, Math.PI * 2)
    c.fill()
    c.globalAlpha = 1
    const isleGrad = c.createLinearGradient(0, islandBase - h * 0.20, 0, islandBase + 10)
    isleGrad.addColorStop(0, skin.islandLight)
    isleGrad.addColorStop(1, skin.island)
    c.fillStyle = isleGrad
    c.beginPath()
    c.ellipse(islandCx, islandBase + 6, w * 0.47 * breath, h * 0.25 * breath, 0, Math.PI, Math.PI * 2)
    c.fill()
    c.fillStyle = 'rgba(238,222,180,0.9)'
    c.beginPath()
    c.ellipse(islandCx, islandBase + 8, w * 0.48, h * 0.055, 0, 0, Math.PI * 2)
    c.fill()
    // 岸边浪花
    c.strokeStyle = 'rgba(255,255,255,0.55)'
    c.lineWidth = 2.4
    for (let k = 0; k < 2; k++) {
      c.beginPath()
      c.ellipse(islandCx, islandBase + 10 + k * 7, w * (0.49 + k * 0.025), h * (0.05 + k * 0.012), 0, 0.15, Math.PI - 0.15)
      c.stroke()
    }

    // 树
    const n: number = skin.trees
    for (let i = 0; i < n; i++) {
      const slot: number[] = TREE_SLOTS[i]
      const x: number = w * (0.5 + (slot[0] - 0.5) * 0.94)
      const baseY: number = islandBase - h * 0.04 - slot[1] * h * 0.34
      const s: number = (1.0 + slot[1] * 0.8) * (1 + this.pulseVal * 0.32)
      this.tree(c, x, baseY, s, skin, this.stage === 0)
    }
    // 灌木
    if (this.stage >= 1) {
      c.fillStyle = skin.canopy
      for (let i = 0; i < 3; i++) {
        c.beginPath()
        c.ellipse(w * (0.33 + i * 0.17), islandBase - h * 0.012, 12, 7.5, 0, 0, Math.PI * 2)
        c.fill()
      }
    }
    // 码头
    if (this.stage >= 2) {
      const dx: number = w * 0.74
      c.fillStyle = '#A0714B'
      c.fillRect(dx, islandBase + h * 0.025, w * 0.11, 5)
      c.fillStyle = '#8B5E3C'
      for (let i = 0; i < 3; i++) {
        c.fillRect(dx + 8 + i * (w * 0.11 - 16) / 2, islandBase + h * 0.025 + 5, 3, 11)
      }
    }
    // 风车(森屿+)
    if (this.stage >= 3) {
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

    // 海面光斑
    if (this.stage >= 2) {
      c.fillStyle = 'rgba(255,255,255,0.5)'
      for (let i = 0; i < 5; i++) {
        const sx: number = w * (0.08 + 0.19 * i) + Math.sin(t + i) * 8
        const sy: number = seaY + h * (0.12 + (i % 3) * 0.07)
        c.fillRect(sx, sy, 15 - (i % 3) * 3, 2)
      }
    }

    // 鱼跃(每 7 秒)
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

    // 萤火虫(森屿+)
    if (this.stage >= 3) {
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
    if (this.stage >= 4) {
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
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.draw()
      })
  }
}
