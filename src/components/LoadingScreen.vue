<script setup>
// 全屏加载动画：3D 粒子背景 + 圆形进度指示器 + 点击进入主站
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import ParticlesBg from '@/components/particles/ParticlesBg.vue'

const emit = defineEmits(['finished'])

const progress = ref(0) // 屏幕上显示的百分比（缓动后的实际值）
const phase = ref('loading') // loading → ready → leaving
const caption = ref('正在唤醒这一处')
const hint = ref('资源加载中')

const RING_R = 54
const RING_C = 2 * Math.PI * RING_R
const offset = computed(() => RING_C * (1 - progress.value / 100))

const MIN_MS = 1500 // 最短展示，保证动效被看见
const MAX_MS = 4600 // 兜底上限，绝不卡死

const reduceMotion =
  typeof window !== 'undefined' &&
  window.matchMedia &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches

let start = 0
let raf = 0
let target = 0
let current = 0
let loadFired = false
let assetsPending = 0
let assetsTotal = 0
let leaveTimer = 0

function preload(src) {
  return new Promise((resolve) => {
    const img = new Image()
    img.onload = img.onerror = () => resolve()
    img.src = src
  })
}

// 加载页背景装饰图（氛围底图，完整显示不裁切）——来自 public/img 资源目录。
// 用 BASE_URL 前缀保证用户页 / 项目页部署下路径都正确；contain 保证整图可见、自适应、无横向滚动。
const POSTER_SRC = (import.meta.env.BASE_URL || '/') + 'img/Blue and Red French Party Poster.png'
const bgStyle = computed(() => ({
  // 一层与页面底色同调的暗化叠加，让海报融为底色而非突兀的图片
  backgroundImage: `linear-gradient(color-mix(in srgb, var(--color-bg-base) 60%, transparent), color-mix(in srgb, var(--color-bg-base) 60%, transparent)), url("${POSTER_SRC}")`,
}))

async function boot() {
  start = performance.now()

  // 关键视觉资源：头像（首屏主视觉），加载完成即计入进度
  const base = import.meta.env.BASE_URL || '/'
  const assets = [base + 'img/avatar.webp']
  assetsTotal = assets.length
  assetsPending = assets.length
  Promise.all(assets.map(preload)).then(() => {
    assetsPending = 0
  })

  // 背景装饰图预热缓存（不计入进度门控，避免影响加载节奏）
  preload(POSTER_SRC)

  const onLoad = () => {
    loadFired = true
  }
  if (document.readyState === 'complete') loadFired = true
  else window.addEventListener('load', onLoad, { once: true })

  tick()
}

function tick() {
  const now = performance.now()
  const elapsed = now - start
  const minReached = elapsed >= MIN_MS

  if ((loadFired && minReached) || elapsed >= MAX_MS) {
    target = 1
  } else {
    const timeP = Math.min(elapsed / MIN_MS, 1)
    const assetP = assetsTotal ? (assetsTotal - assetsPending) / assetsTotal : 1
    target = Math.max(0.12 + timeP * 0.78, 0.12 + assetP * 0.5)
  }

  // 缓动逼近目标，数字滚动顺滑
  current += (target * 100 - current) * (reduceMotion ? 0.5 : 0.07)
  if (target === 1 && current > 99.4) current = 100

  progress.value = current

  if (current >= 100) {
    // 加载完成：不自动跳转，等待用户主动点击进入
    phase.value = 'ready'
    caption.value = '已就绪'
    hint.value = '点击任意处，或按下方的「进入」'
    return
  }
  raf = requestAnimationFrame(tick)
}

function enter() {
  if (phase.value !== 'ready') return
  phase.value = 'leaving'
  leaveTimer = window.setTimeout(
    () => emit('finished'),
    reduceMotion ? 220 : 940
  )
}

onMounted(boot)

onBeforeUnmount(() => {
  cancelAnimationFrame(raf)
  clearTimeout(leaveTimer)
})
</script>

<template>
  <div
    class="loader"
    :class="{ 'is-ready': phase === 'ready', 'is-leaving': phase === 'leaving' }"
    role="button"
    :tabindex="phase === 'ready' ? 0 : -1"
    :aria-label="phase === 'ready' ? '加载完成，点击或按回车进入' : `加载中，${Math.round(progress)}%`"
    :aria-disabled="phase !== 'ready'"
    @click="enter"
    @keydown.enter.prevent="enter"
    @keydown.space.prevent="enter"
  >
    <!-- 背景装饰图：氛围底图，置于粒子层之下，压暗处理不与内容争视线 -->
    <div class="loader-bg-img" :style="bgStyle" aria-hidden="true"></div>
    <ParticlesBg class="loader-particles" :density="2.6" />
    <div class="loader-veil" aria-hidden="true"></div>

    <div class="loader-core">
      <div class="brand">
        <span class="brand-mark">温</span>
        <span class="brand-name">温暖</span>
      </div>

      <p class="loader-caption">{{ caption }}</p>

      <!-- 圆形进度指示器 -->
      <div class="ring-wrap" :aria-hidden="true">
        <svg class="ring" viewBox="0 0 120 120">
          <defs>
            <linearGradient id="ringGrad" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stop-color="var(--color-accent)" />
              <stop offset="100%" stop-color="var(--color-link)" />
            </linearGradient>
          </defs>
          <circle class="ring-track" cx="60" cy="60" :r="RING_R" />
          <circle
            class="ring-fill"
            cx="60"
            cy="60"
            :r="RING_R"
            :stroke-dasharray="RING_C"
            :stroke-dashoffset="offset"
          />
        </svg>
        <div class="ring-center">
          <span class="pct">{{ Math.round(progress) }}<i>%</i></span>
        </div>
      </div>

      <button
        v-if="phase === 'ready'"
        type="button"
        class="enter-btn"
        @click.stop="enter"
      >
        进入这一处 <span aria-hidden="true">→</span>
      </button>
      <span v-else class="hint">{{ hint }}</span>
    </div>
  </div>
</template>

<style scoped>
.loader {
  position: fixed;
  inset: 0;
  z-index: 2000;
  display: grid;
  place-items: center;
  overflow: hidden;
  color: var(--color-text-base);
  background:
    radial-gradient(
      130% 120% at 50% -10%,
      color-mix(in srgb, var(--color-accent) 26%, var(--color-bg-base)),
      var(--color-bg-base) 58%
    );
  transition:
    opacity 0.94s var(--ease-standard),
    transform 0.94s var(--ease-standard),
    filter 0.94s var(--ease-standard);
  will-change: opacity, transform, filter;
}

.loader.is-ready {
  cursor: pointer;
}

.loader.is-leaving {
  opacity: 0;
  transform: scale(1.06);
  filter: blur(10px);
  pointer-events: none;
}

.loader-particles {
  position: absolute;
  inset: 0;
}

/* 背景装饰图：完整显示整张海报（contain，不裁切、保持原始宽高比），
   偏右放置、轻微压暗与柔化，置于粒子层之下，作为氛围底图不抢内容。
   入场用自然淡入+轻微位移，避免突兀出现（尊重 reduce-motion）。 */
.loader-bg-img {
  position: absolute;
  /* 略多超出视口，配合父级 overflow:hidden，放大漂浮幅度时也不会露出边缘或产生滚动条 */
  inset: -8vmax;
  background-position: right center;
  background-size: contain;
  background-repeat: no-repeat;
  filter: saturate(0.92) blur(2px);
  pointer-events: none;
  opacity: 0;
  /* 入场淡入右滑 + 之后无限循环轻微漂浮/呼吸缩放，让海报"活"起来 */
  animation:
    bgImgIn 1.1s cubic-bezier(0.22, 0.61, 0.36, 1) 0.3s forwards,
    bgFloat 8s ease-in-out 1.5s infinite;
}
@keyframes bgImgIn {
  from {
    opacity: 0;
    transform: translateX(26px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}
@keyframes bgFloat {
  0% {
    transform: translate3d(0, 0, 0) scale(1) rotate(0deg);
  }
  25% {
    transform: translate3d(-34px, 22px, 0) scale(1.12) rotate(-1.2deg);
  }
  50% {
    transform: translate3d(30px, -18px, 0) scale(1.08) rotate(1deg);
  }
  75% {
    transform: translate3d(-20px, -24px, 0) scale(1.1) rotate(-0.8deg);
  }
  100% {
    transform: translate3d(0, 0, 0) scale(1) rotate(0deg);
  }
}
@media (prefers-reduced-motion: reduce) {
  .loader-bg-img {
    animation: none;
    opacity: 1;
    transform: none;
  }
}

/* 中心柔光，避免粒子过亮刺眼 */
.loader-veil {
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: radial-gradient(
    62% 62% at 50% 50%,
    transparent,
    color-mix(in srgb, var(--color-bg-base) 72%, transparent)
  );
}

.loader-core {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1.15rem;
  padding: 2rem;
  text-align: center;
  animation: coreIn 0.9s var(--ease-emphasis) both;
}

@keyframes coreIn {
  from {
    opacity: 0;
    transform: translateY(16px) scale(0.98);
  }
  to {
    opacity: 1;
    transform: none;
  }
}

.brand {
  display: flex;
  align-items: center;
  gap: 0.65rem;
}

.brand-mark {
  width: 46px;
  height: 46px;
  border-radius: 14px;
  display: grid;
  place-items: center;
  font-weight: 800;
  font-size: 1.35rem;
  color: var(--color-text-on-accent);
  background: linear-gradient(
    135deg,
    var(--color-accent),
    var(--color-accent-hover)
  );
  box-shadow: 0 10px 34px rgba(var(--color-shadow), 0.28);
  animation: floatY 3.2s ease-in-out infinite;
}

.brand-name {
  font-size: 1.5rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  background: linear-gradient(
    90deg,
    var(--color-text-base),
    var(--color-link),
    var(--color-text-base)
  );
  background-size: 220% auto;
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
  animation: shine 4.5s linear infinite;
}

@keyframes floatY {
  50% {
    transform: translateY(-6px);
  }
}

@keyframes shine {
  to {
    background-position: 220% center;
  }
}

.loader-caption {
  margin: 0;
  color: var(--color-text-muted);
  font-size: clamp(0.9rem, 2.6vw, 1.05rem);
  letter-spacing: 0.1em;
}

/* —— 圆形进度 —— */
.ring-wrap {
  position: relative;
  width: clamp(150px, 42vw, 210px);
  aspect-ratio: 1 / 1;
  display: grid;
  place-items: center;
}

/* 柔光池：让进度环的辉光融入背景，而不是悬浮成一圈割裂的亮边。
   颜色与加载页环境光（约 26% accent）对齐，作为环后的一层柔和光晕。 */
.ring-wrap::before {
  content: "";
  position: absolute;
  inset: -16%;
  border-radius: 50%;
  background: radial-gradient(
    closest-side,
    color-mix(in srgb, var(--color-accent) 20%, transparent),
    transparent 76%
  );
  filter: blur(3px);
  pointer-events: none;
}

.ring {
  width: 100%;
  height: 100%;
  transform: rotate(-90deg); /* 从正上方开始 */
}

.ring-track {
  fill: none;
  stroke: color-mix(in srgb, var(--color-border) 80%, transparent);
  stroke-width: 6;
}

.ring-fill {
  fill: none;
  stroke: url(#ringGrad);
  stroke-width: 6;
  stroke-linecap: round;
  /* 辉光改为半透明 accent 并加大模糊，与加载页环境光（约 26% accent）对齐，
     避免亮边与背景割裂；光池见 .ring-wrap::before */
  filter: drop-shadow(0 0 7px color-mix(in srgb, var(--color-accent) 40%, transparent));
  transition: stroke-dashoffset 0.18s linear;
}

.ring-center {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
}

.pct {
  font-size: clamp(2rem, 8vw, 3rem);
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  line-height: 1;
}

.pct i {
  font-size: 0.5em;
  font-style: normal;
  margin-left: 2px;
  color: var(--color-text-muted);
}

/* 就绪态呼吸提示 */
.loader.is-ready .ring-wrap {
  animation: ringPulse 2.4s ease-in-out infinite;
}

@keyframes ringPulse {
  0%,
  100% {
    transform: scale(1);
  }
  50% {
    transform: scale(1.04);
  }
}

.enter-btn {
  margin-top: 0.2rem;
  padding: 0.7rem 1.8rem;
  border: none;
  border-radius: 99px;
  font-size: 1rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  color: var(--color-text-on-accent);
  background: linear-gradient(
    135deg,
    var(--color-accent),
    var(--color-link)
  );
  box-shadow: 0 10px 30px rgba(var(--color-shadow), 0.32);
  transition: transform 0.2s var(--ease-emphasis),
    box-shadow 0.2s ease;
  animation: btnIn 0.5s var(--ease-emphasis) both;
}

.enter-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 14px 38px rgba(var(--color-shadow), 0.4);
}

.enter-btn:active {
  transform: translateY(0);
}

@keyframes btnIn {
  from {
    opacity: 0;
    transform: translateY(10px) scale(0.96);
  }
  to {
    opacity: 1;
    transform: none;
  }
}

.hint {
  font-size: 0.8rem;
  color: var(--color-text-muted);
  letter-spacing: 0.12em;
}

@media (prefers-reduced-motion: reduce) {
  .loader,
  .loader.is-leaving {
    transition: opacity 0.2s linear;
    transform: none;
    filter: none;
  }
  .brand-mark,
  .brand-name,
  .loader-core,
  .loader.is-ready .ring-wrap,
  .enter-btn {
    animation: none !important;
  }
}
</style>
