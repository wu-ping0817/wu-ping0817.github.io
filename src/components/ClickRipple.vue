<script setup>
// 全局点击反馈：监听整页 click，在点击处生成并播放反馈动效。
// 在原有「统一涟漪」基础上扩展为多种可切换的点击动画：
//   - 通过 data-fx 在【不同元素 / 场景】指定动画类型：
//       ripple（默认/经典涟漪）· bounce（缩放弹跳）· nudge（位移微动）
//       · color（颜色渐变）· shadow（阴影变化）；
//   - data-fx="random" 时，每次点击随机展示一种，避免单调；
//   - 未设置 data-fx 的元素沿用原 ripple 行为，向后兼容。
// 所有效果 pointer-events:none、不 preventDefault，绝不拦截 / 延迟交互；
// 仅用 transform / opacity（合成层友好），并有并发上限与兜底清理，兼顾性能；
// prefers-reduced-motion 下位移类降级为不播放，颜色/阴影保留快速低强度反馈。
// 视觉样式集中在全局 click-feedback.css，便于统一维护。
import { ref, onMounted, onBeforeUnmount } from 'vue'

// 命中以下选择器时，动效锚定到该元素内部（聚焦反馈）
const CLICKABLE =
  'a,button,.btn,[role="button"],.card,.nav-link,.mystery-board,' +
  'input[type="submit"],input[type="button"],.pill,.chip,summary,' +
  '.accordion,label'

const TYPES = ['ripple', 'bounce', 'color', 'shadow', 'nudge']
const CAP = 60 // 并发动效上限，防止高频点击拖慢页面
let active = 0

const layer = ref(null)
let reduce = false

function pickType(fx) {
  if (fx === 'random') return TYPES[Math.floor(Math.random() * TYPES.length)]
  if (TYPES.includes(fx)) return fx
  return 'ripple'
}

// 仅当宿主无定位上下文时补充，避免坐标错乱（复用既有 .ripple-host）
function ensureHost(host) {
  if (getComputedStyle(host).position === 'static') {
    host.classList.add('ripple-host')
  }
}

// —— 经典涟漪（原有行为，注入 .ripple-dot 到元素内部） ——
function spawnRippleInHost(host, x, y) {
  const rect = host.getBoundingClientRect()
  if (!x && !y) {
    x = rect.left + rect.width / 2
    y = rect.top + rect.height / 2
  }
  const size = Math.max(rect.width, rect.height) * 2.4
  const dot = document.createElement('span')
  dot.className = 'ripple-dot'
  dot.style.width = dot.style.height = size + 'px'
  dot.style.left = x - rect.left + 'px'
  dot.style.top = y - rect.top + 'px'
  ensureHost(host)
  host.appendChild(dot)
  dot.addEventListener('animationend', () => dot.remove(), { once: true })
  setTimeout(() => dot.remove(), 900) // 兜底清理
}

// —— 作用于宿主自身的缩放弹跳 / 位移微动 ——
function runHostAnim(host, cls, setup) {
  // 连点：取消上一次同类型动画后重播
  if (host._fxTimers && host._fxTimers[cls]) host._fxTimers[cls]()
  if (setup) setup()
  host.classList.remove(cls)
  void host.offsetWidth // 强制回流，支持连点重播
  host.classList.add(cls)
  active++
  let cancelled = false
  const finish = () => {
    if (cancelled) return
    cancelled = true
    host.classList.remove(cls)
    host.removeEventListener('animationend', finish)
    if (host._fxTimers) delete host._fxTimers[cls]
    active--
  }
  host.addEventListener('animationend', finish)
  if (!host._fxTimers) host._fxTimers = {}
  host._fxTimers[cls] = finish
}

// —— 宿主内叠加层：颜色渐变 / 阴影变化 ——
function spawnOverlay(host, type) {
  if (active >= CAP) return
  ensureHost(host)
  const span = document.createElement('span')
  span.className = type === 'color' ? 'fx-color' : 'fx-shadow'
  span.style.setProperty('--fx-color', 'var(--color-accent)')
  host.appendChild(span)
  active++
  let cleaned = false
  const cleanup = () => {
    if (cleaned) return
    cleaned = true
    span.remove()
    active--
  }
  span.addEventListener('animationend', cleanup)
  setTimeout(cleanup, 1000)
}

function spawnEffect(host, x, y, type) {
  if (type === 'ripple') {
    spawnRippleInHost(host, x, y)
    return
  }
  if (active >= CAP) return
  if (type === 'bounce') {
    runHostAnim(host, 'fx-bounce')
    return
  }
  if (type === 'nudge') {
    const a = Math.random() * Math.PI * 2
    const d = 3 + Math.random() * 5
    runHostAnim(host, 'fx-nudge', () => {
      host.style.setProperty('--fx-dx', (Math.cos(a) * d).toFixed(1) + 'px')
      host.style.setProperty('--fx-dy', (Math.sin(a) * d).toFixed(1) + 'px')
    })
    return
  }
  // color / shadow 叠加层
  spawnOverlay(host, type)
}

// 固定层全局涟漪（空白区域点击）：沿用原行为
function spawnAtPoint(x, y) {
  if (!layer.value) return
  const size = Math.max(window.innerWidth, window.innerHeight) * 0.26
  const dot = document.createElement('span')
  dot.className = 'ripple-dot'
  dot.style.width = dot.style.height = size + 'px'
  dot.style.left = x + 'px'
  dot.style.top = y + 'px'
  layer.value.appendChild(dot)
  dot.addEventListener('animationend', () => dot.remove(), { once: true })
  setTimeout(() => dot.remove(), 900)
}

function onPointer(e) {
  const x = e.clientX
  const y = e.clientY
  const target = e.target && e.target.closest ? e.target : null
  const host = target ? target.closest(CLICKABLE) : null
  // 读取该元素（或就近祖先）配置的动画类型
  const fxEl = target ? target.closest('[data-fx]') : null
  const fx = (fxEl && fxEl.dataset.fx) || (host && host.dataset.fx) || 'ripple'
  const chosen = pickType(fx)
  if (host && host !== document.documentElement && host !== document.body) {
    // 减弱动效：位移类（弹跳/微动）不播放，回退到颜色淡入（仍属“状态变化”，允许保留）
    if (reduce && (chosen === 'bounce' || chosen === 'nudge')) {
      spawnEffect(host, x, y, 'color')
    } else {
      spawnEffect(host, x, y, chosen)
    }
  } else {
    spawnAtPoint(x, y)
  }
}

onMounted(() => {
  reduce =
    typeof window !== 'undefined' &&
    window.matchMedia &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  // 监听整页 click：被动、冒泡阶段；不 preventDefault / stopPropagation，
  // 因此任何可点击区域乃至页面空白处都会触发，且不影响真实目标的事件逻辑。
  document.addEventListener('click', onPointer, { passive: true })
})
onBeforeUnmount(() => {
  document.removeEventListener('click', onPointer)
})
</script>

<template>
  <!-- 固定全屏覆盖层：置于内容之上、加载遮罩之下；pointer-events:none 不拦截任何点击 -->
  <div ref="layer" class="ripple-layer" aria-hidden="true"></div>
</template>

<style scoped>
.ripple-layer {
  position: fixed;
  inset: 0;
  z-index: 1500;
  pointer-events: none;
  overflow: hidden;
}
</style>
