<script setup>
// 沉浸式粒子背景 v2：多层级粒子系统
// 层级（由远及近）：体积光晕(orbs) → 3D 景深星场(stars) → 星座节点网络(nodes) → 2D 星尘/散景(motes) → 前景流光(streaks)
// 特性：主题色衍生协调调色板、响应式密度(按面积 + DPR 适配)、reduced-motion 静态降级、性能预算内运行。
import { ref, onMounted, onBeforeUnmount } from 'vue'

// 密度倍数：加载动画可传更高值（如 2.6）以显著增多粒子；
// 全站共享背景不传，维持默认 1。
const props = defineProps({
  density: { type: Number, default: 1 },
})

const canvasRef = ref(null)
let ctx = null
let raf = 0
let w = 0
let h = 0
let dpr = 1
let cx = 0
let cy = 0
let fov = 0
let accent = [182, 212, 246] // 默认辅色 #b6d4f6
let palette = [accent, accent, accent] // 由主题辅色衍生的协调调色板
let stars = [] // 3D 景深星点（远景层）
let orbs = [] // 体积光晕（最远背景层）
let nodes = [] // 星座节点网络（中景层，数量有界）
let motes = [] // 2D 前景星尘 / 散景（中前景层）
let streaks = [] // 前景流光 / 拖尾（最近层）
let t = 0
let ro = null

const reduceMotion =
  typeof window !== 'undefined' &&
  window.matchMedia &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches

function readAccent() {
  const raw =
    getComputedStyle(document.documentElement)
      .getPropertyValue('--color-accent')
      .trim() || '#b6d4f6'
  const hex = raw.replace('#', '')
  const full =
    hex.length === 3
      ? hex.split('').map((c) => c + c).join('')
      : hex
  const n = parseInt(full, 16)
  if (Number.isNaN(n)) return [182, 212, 246]
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255]
}

function rand(a, b) {
  return a + Math.random() * (b - a)
}

function clamp255(v) {
  return v < 0 ? 0 : v > 255 ? 255 : v | 0
}

function mixRGB(a, b, tt) {
  return [
    clamp255(a[0] + (b[0] - a[0]) * tt),
    clamp255(a[1] + (b[1] - a[1]) * tt),
    clamp255(a[2] + (b[2] - a[2]) * tt),
  ]
}

function lighten(c, tt) {
  return mixRGB(c, [255, 255, 255], tt)
}

// 粒子始终铺满视口、持续渲染与运动：不与任何 UI 元素发生遮挡判定 / 碰撞销毁，
// 也不因被卡片、导航、浮层等组件覆盖而消失或隐藏。粒子在整片画布上连续存在，
// 自然地从组件上方或底部「穿透」流过，实现连贯的纵深动效。

function resize() {
  const el = canvasRef.value
  if (!el) return
  const parent = el.parentElement
  w = parent.clientWidth || window.innerWidth
  h = parent.clientHeight || window.innerHeight
  cx = w / 2
  cy = h / 2
  fov = Math.min(w, h) * 0.9
  dpr = Math.min(window.devicePixelRatio || 1, 2)
  el.width = Math.round(w * dpr)
  el.height = Math.round(h * dpr)
  el.style.width = w + 'px'
  el.style.height = h + 'px'
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
  accent = readAccent()
  // 由主题辅色衍生 3 色协调调色板（主色 / 提亮 / 柔白混合），保持整体视觉统一
  palette = [accent, lighten(accent, 0.45), mixRGB(accent, [255, 255, 255], 0.32)]
  initScene()
  if (reduceMotion) drawStatic()
}

function spawnStreak(initial) {
  return {
    x: initial ? rand(0, w) : -rand(20, 160),
    y: rand(0, h),
    vx: rand(1.2, 2.6),
    vy: rand(-0.5, 0.5),
    len: rand(40, 110),
    life: 0,
    max: rand(180, 360),
    pal: (Math.random() * palette.length) | 0,
    a: rand(0.5, 0.95),
  }
}

function initScene() {
  const area = w * h
  const d = props.density || 1

  // —— 3D 景深星场（远景层）：数量提升 + 尺寸 / 漂移 / 摆动多样性 ——
  const starCount = Math.max(80, Math.min(1000, Math.round((area / 9000) * d)))
  stars = []
  for (let i = 0; i < starCount; i++) {
    stars.push({
      x: rand(-1, 1),
      y: rand(-1, 1),
      z: rand(0.16, 1),
      speed: rand(0.0008, 0.0035), // 降低前涌速度 → 单颗星点可见寿命更长、更持久自然
      dx: rand(-0.0006, 0.0006), // 横向漂移，丰富运动轨迹
      dy: rand(-0.0006, 0.0006),
      sway: rand(0.0002, 0.0009), // 轻微摆动相位，轨迹更有机
      swayPh: rand(0, Math.PI * 2),
      sz0: rand(0.7, 1.5), // 尺寸差异
      pal: (Math.random() * palette.length) | 0,
      glow: false,
    })
  }
  // 仅少量星点带柔光（预算内，避免 shadowBlur 全量开销）
  let glowBudget = Math.min(70, Math.round(starCount * 0.1))
  for (const p of stars) {
    if (glowBudget > 0 && Math.random() < 0.5) {
      p.glow = true
      glowBudget--
    }
  }

  // —— 体积光晕（最远背景层，营造前后景深）——
  const orbCount = (w < 640 ? 3 : 5) + Math.round(3 * d)
  orbs = []
  for (let i = 0; i < orbCount; i++) {
    const depth = rand(0.35, 1)
    orbs.push({
      x: rand(0.15, 0.85) * w,
      y: rand(0.15, 0.85) * h,
      depth,
      r: rand(120, 260) * depth,
      vx: rand(-0.12, 0.12),
      vy: rand(-0.12, 0.12),
      ph: rand(0, Math.PI * 2),
    })
  }

  // —— 星座节点网络（中景层）：数量有界，保证连线开销恒定 ——
  const nodeCount = Math.min(90, Math.max(24, Math.round(area / 30000)))
  nodes = []
  for (let i = 0; i < nodeCount; i++) {
    nodes.push({
      x: rand(0, w),
      y: rand(0, h),
      vx: (Math.random() - 0.5) * 0.22,
      vy: (Math.random() - 0.5) * 0.22,
      r: rand(0.8, 1.9),
      pal: (Math.random() * palette.length) | 0,
      tw: rand(0, Math.PI * 2),
      a: rand(0.3, 0.7),
    })
  }

  // —— 2D 前景星尘（中前景层）：密度提升 + 少量散景(bokeh)增加层次 ——
  const moteCount = Math.max(40, Math.min(460, Math.round((area / 16000) * d)))
  motes = []
  for (let i = 0; i < moteCount; i++) {
    const bokeh = Math.random() < 0.12
    motes.push({
      x: Math.random() * w,
      y: Math.random() * h,
      vx: (Math.random() - 0.5) * (bokeh ? 0.18 : 0.5),
      vy: (Math.random() - 0.5) * (bokeh ? 0.18 : 0.5),
      r: bokeh ? rand(2.2, 4.6) : rand(0.4, 2.6),
      a: bokeh ? rand(0.08, 0.2) : rand(0.15, 0.6),
      tw: rand(0, Math.PI * 2),
      pal: (Math.random() * palette.length) | 0,
      bokeh,
    })
  }

  // —— 前景流光（最近层）：少量斜向拖尾，增强运动轨迹多样性 ——
  const streakCount = Math.min(8, 3 + Math.round(d))
  streaks = []
  for (let i = 0; i < streakCount; i++) streaks.push(spawnStreak(true))
}

function drawStatic() {
  // 降级：绘制一帧静态星点（3D 投影 + 节点 + 星尘），不驱动动画
  ctx.clearRect(0, 0, w, h)
  for (const p of stars) {
    const nz = Math.max(0.16, Math.abs(p.z))
    const k = fov / nz
    const sx = cx + p.x * k
    const sy = cy + p.y * k
    const size = Math.min(9, 1.6 * (1 / nz) * p.sz0)
    const fade = Math.min((1 - p.z) / 0.1, (p.z - 0.16) / 0.26, 1)
    const col = palette[p.pal]
    const alpha = Math.min(1, Math.max(0.06, (1 - nz) * 1.05 + 0.12)) * Math.max(0, fade)
    if (alpha <= 0.01) continue
    ctx.beginPath()
    ctx.arc(sx, sy, size, 0, Math.PI * 2)
    ctx.fillStyle = `rgba(${col[0]},${col[1]},${col[2]},${alpha})`
    ctx.fill()
  }
  for (const n of nodes) {
    const col = palette[n.pal]
    ctx.beginPath()
    ctx.arc(n.x, n.y, n.r, 0, Math.PI * 2)
    ctx.fillStyle = `rgba(${col[0]},${col[1]},${col[2]},${n.a})`
    ctx.fill()
  }
  const LINK = 120
  for (let i = 0; i < nodes.length; i++) {
    for (let j = i + 1; j < nodes.length; j++) {
      const a = nodes[i]
      const b = nodes[j]
      const dx = a.x - b.x
      const dy = a.y - b.y
      const dist = Math.sqrt(dx * dx + dy * dy)
      if (dist < LINK) {
        const o = (1 - dist / LINK) * 0.14
        const c0 = palette[a.pal]
        ctx.beginPath()
        ctx.moveTo(a.x, a.y)
        ctx.lineTo(b.x, b.y)
        ctx.strokeStyle = `rgba(${c0[0]},${c0[1]},${c0[2]},${o})`
        ctx.lineWidth = 1
        ctx.stroke()
      }
    }
  }
  for (const m of motes) {
    const col = palette[m.pal]
    ctx.beginPath()
    ctx.arc(m.x, m.y, m.r, 0, Math.PI * 2)
    ctx.fillStyle = `rgba(${col[0]},${col[1]},${col[2]},${m.a})`
    ctx.fill()
  }
}

function draw() {
  t += 1
  const [r, g, b] = accent
  ctx.clearRect(0, 0, w, h)

  // —— 体积光晕（最远背景层）——
  for (const o of orbs) {
    o.x += o.vx
    o.y += o.vy
    if (o.x < -o.r) o.x = w + o.r
    if (o.x > w + o.r) o.x = -o.r
    if (o.y < -o.r) o.y = h + o.r
    if (o.y > h + o.r) o.y = -o.r
    const pulse = 0.7 + 0.3 * Math.sin(t * 0.01 + o.ph)
    const a = 0.16 * o.depth * pulse
    const grad = ctx.createRadialGradient(o.x, o.y, 0, o.x, o.y, o.r)
    grad.addColorStop(0, `rgba(${r},${g},${b},${a})`)
    grad.addColorStop(1, `rgba(${r},${g},${b},0)`)
    ctx.fillStyle = grad
    ctx.beginPath()
    ctx.arc(o.x, o.y, o.r, 0, Math.PI * 2)
    ctx.fill()
  }

  // —— 3D 景深星场（前涌 + 偏航视差 + 漂移 / 摆动）——
  const ay = t * 0.0016 // 缓慢偏航，产生 3D 旋转感
  const s = Math.sin(ay)
  const c = Math.cos(ay)
  for (const p of stars) {
    p.x += p.dx
    p.y += p.dy
    p.z -= p.speed
    if (p.z <= 0.16) {
      p.z = 1
      p.x = rand(-1, 1)
      p.y = rand(-1, 1)
    }
    // 摆动 + 旋转后取正深度（仅用于投影位置 / 尺寸 / 亮度）
    const swayX = Math.sin(t * p.sway + p.swayPh) * 0.04
    const px = p.x + swayX
    const nx = px * c - p.z * s
    const nz = Math.max(0.16, Math.abs(px * s + p.z * c))
    const k = fov / nz
    const sx = cx + nx * k
    const sy = cy + p.y * k
    const size = Math.min(14, 2.0 * (1 / nz) * p.sz0)
    // 平滑生命周期过渡：基于真实深度 p.z（随前涌单调，与偏航无关），中途绝不因旋转骤隐
    const birth = Math.max(0, Math.min(1, (1 - p.z) / 0.1))
    const death = Math.max(0, Math.min(1, (p.z - 0.16) / 0.26))
    const fade = Math.min(birth, death)
    const sz = size * (0.35 + 0.65 * fade) // 淡出时同步收缩，柔和过渡
    const col = palette[p.pal]
    const alpha = Math.min(1, Math.max(0.06, (1 - nz) * 1.05 + 0.12)) * fade
    if (alpha <= 0.01) continue
    // 少量星点带柔光：用低透明度大圆晕替代 shadowBlur，开销恒定且廉价
    if (p.glow) {
      ctx.beginPath()
      ctx.arc(sx, sy, sz * 2.4, 0, Math.PI * 2)
      ctx.fillStyle = `rgba(${col[0]},${col[1]},${col[2]},${alpha * 0.22})`
      ctx.fill()
    }
    ctx.beginPath()
    ctx.arc(sx, sy, sz, 0, Math.PI * 2)
    ctx.fillStyle = `rgba(${col[0]},${col[1]},${col[2]},${alpha})`
    ctx.fill()
  }

  // —— 星座节点网络（中景层）——
  for (const n of nodes) {
    n.x += n.vx
    n.y += n.vy
    n.tw += 0.02
    if (n.x < 0 || n.x > w) n.vx *= -1
    if (n.y < 0 || n.y > h) n.vy *= -1
  }
  for (const n of nodes) {
    const col = palette[n.pal]
    const alpha = n.a * (0.7 + 0.3 * Math.sin(n.tw))
    ctx.beginPath()
    ctx.arc(n.x, n.y, n.r, 0, Math.PI * 2)
    ctx.fillStyle = `rgba(${col[0]},${col[1]},${col[2]},${alpha})`
    ctx.fill()
  }
  const LINK = 120
  for (let i = 0; i < nodes.length; i++) {
    for (let j = i + 1; j < nodes.length; j++) {
      const a = nodes[i]
      const c2 = nodes[j]
      const dx = a.x - c2.x
      const dy = a.y - c2.y
      const dist = Math.sqrt(dx * dx + dy * dy)
      if (dist < LINK) {
        const o = (1 - dist / LINK) * 0.14
        const c0 = palette[a.pal]
        ctx.beginPath()
        ctx.moveTo(a.x, a.y)
        ctx.lineTo(c2.x, c2.y)
        ctx.strokeStyle = `rgba(${c0[0]},${c0[1]},${c0[2]},${o})`
        ctx.lineWidth = 1
        ctx.stroke()
      }
    }
  }

  // —— 2D 前景星尘 / 散景（中前景层）——
  for (const m of motes) {
    m.x += m.vx
    m.y += m.vy
    m.tw += 0.02
    if (m.x < 0 || m.x > w) m.vx *= -1
    if (m.y < 0 || m.y > h) m.vy *= -1
    // 减弱明灭幅度（0.72~1.0），使星尘更持久、过渡更自然
    const alpha = m.a * (0.72 + 0.28 * Math.sin(m.tw))
    if (alpha <= 0.01) continue
    const col = palette[m.pal]
    ctx.beginPath()
    ctx.arc(m.x, m.y, m.r, 0, Math.PI * 2)
    ctx.fillStyle = `rgba(${col[0]},${col[1]},${col[2]},${alpha})`
    ctx.fill()
  }

  // —— 前景流光 / 拖尾（最近层）——
  for (const st of streaks) {
    st.life += 1
    st.x += st.vx
    st.y += st.vy
    if (st.life > st.max || st.x > w + st.len || st.y > h + st.len || st.y < -st.len) {
      Object.assign(st, spawnStreak(false))
      continue
    }
    const col = palette[st.pal]
    const fade = Math.sin(Math.PI * Math.min(1, st.life / st.max)) // 头尾渐隐，轨迹完整
    const len = Math.hypot(st.vx, st.vy)
    const tx = st.x - (st.vx / len) * st.len
    const ty = st.y - (st.vy / len) * st.len
    const grad = ctx.createLinearGradient(st.x, st.y, tx, ty)
    grad.addColorStop(0, `rgba(${col[0]},${col[1]},${col[2]},${st.a * fade})`)
    grad.addColorStop(1, `rgba(${col[0]},${col[1]},${col[2]},0)`)
    ctx.strokeStyle = grad
    ctx.lineWidth = 1.6
    ctx.lineCap = 'round'
    ctx.beginPath()
    ctx.moveTo(st.x, st.y)
    ctx.lineTo(tx, ty)
    ctx.stroke()
  }

  raf = requestAnimationFrame(draw)
}

onMounted(() => {
  const el = canvasRef.value
  if (!el) return
  ctx = el.getContext('2d')
  resize()
  if (!reduceMotion) raf = requestAnimationFrame(draw)
  if (typeof ResizeObserver !== 'undefined') {
    ro = new ResizeObserver(() => resize())
    ro.observe(el.parentElement)
  } else {
    window.addEventListener('resize', resize)
  }
})

onBeforeUnmount(() => {
  cancelAnimationFrame(raf)
  if (ro) ro.disconnect()
  else window.removeEventListener('resize', resize)
})
</script>

<template>
  <canvas ref="canvasRef" class="particles" aria-hidden="true"></canvas>
</template>

<style scoped>
.particles {
  display: block;
  width: 100%;
  height: 100%;
  pointer-events: none;
}
</style>
