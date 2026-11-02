<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import ThemeToggle from '@/components/ThemeToggle.vue'

const router = useRouter()
const route = useRoute()

// 逐页浏览的固定顺序：首页 → 关于我 → 作品 → 联系
const steps = [
  { path: '/', label: '首页', icon: 'home' },
  { path: '/about', label: '关于我', icon: 'about' },
  { path: '/portfolio', label: '作品', icon: 'portfolio' },
  { path: '/contact', label: '联系', icon: 'contact' },
]

// 各步骤对应的图标（与 RouteFX 过渡装饰层保持一致，统一视觉语言）
const ICONS = {
  home: 'M3 11.5 12 4l9 7.5M5.5 10v9.5h13V10',
  about:
    'M12 12.5a3.8 3.8 0 100-7.6 3.8 3.8 0 000 7.6zM4.5 20a7.5 7.5 0 0115 0',
  portfolio:
    'M4 7l8-3.2L20 7l-8 3.2L4 7zm0 5l8 3.2 8-3.2M4 17l8 3.2 8-3.2',
  contact: 'M4 6.5h16v11H4zM4.5 7.5 12 12l7.5-4.5',
}

const current = computed(() => {
  const i = steps.findIndex((s) => s.path === route.path)
  return i < 0 ? 0 : i
})
const isFirst = computed(() => current.value === 0)
const isLast = computed(() => current.value === steps.length - 1)

// 进度轨道填充比例（0% → 100%）
const fillPct = computed(() =>
  steps.length > 1 ? (current.value / (steps.length - 1)) * 100 : 0
)

function go(path) {
  if (path !== route.path) router.push(path)
}
function prev() {
  if (!isFirst.value) go(steps[current.value - 1].path)
}
function next() {
  if (!isLast.value) go(steps[current.value + 1].path)
}
</script>

<template>
  <nav class="sitenav" aria-label="页面导航">
    <button class="brand" type="button" @click="go('/')">温暖</button>

    <div class="dots" role="tablist" aria-label="页面进度">
      <span class="track" aria-hidden="true">
        <span class="track-fill" :style="{ width: fillPct + '%' }"></span>
      </span>
      <button
        v-for="(s, i) in steps"
        :key="s.path"
        class="dot"
        :class="{ active: i === current, done: i < current }"
        type="button"
        role="tab"
        :aria-selected="i === current"
        :aria-label="`第 ${i + 1} 页：${s.label}`"
        @click="go(s.path)"
      >
        <svg class="dot-ico" viewBox="0 0 24 24" aria-hidden="true">
          <path
            :d="ICONS[s.icon]"
            fill="none"
            stroke="currentColor"
            stroke-width="1.9"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </button>
    </div>

    <div class="actions">
      <button
        class="navbtn"
        type="button"
        :disabled="isFirst"
        @click="prev"
        aria-label="上一页"
      >
        <svg class="ico ico-prev" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M15 6l-6 6 6 6" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
        <span>上一步</span>
      </button>
      <ThemeToggle />
      <button
        class="navbtn navbtn--primary"
        type="button"
        :disabled="isLast"
        @click="next"
        aria-label="下一页"
      >
        <span>下一步</span>
        <svg class="ico ico-next" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M9 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </button>
    </div>
  </nav>
</template>

<style scoped>
.sitenav {
  position: fixed;
  left: 50%;
  bottom: 1.1rem;
  transform: translateX(-50%);
  z-index: 50;
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.5rem 0.7rem;
  border-radius: 999px;
  background: color-mix(in srgb, var(--color-bg-base) 78%, transparent);
  -webkit-backdrop-filter: blur(14px) saturate(140%);
  backdrop-filter: blur(14px) saturate(140%);
  border: 1px solid color-mix(in srgb, var(--color-border) 70%, transparent);
  box-shadow: 0 10px 34px -14px rgba(0, 0, 0, 0.55);
  max-width: calc(100% - 2rem);
}
/* 过渡期间（body.is-transitioning）：关闭玻璃模糊，避免装饰面板在其后移动时
   「模糊套模糊」逐帧重算造成卡顿；以更实的底色补偿通透感 */
body.is-transitioning .sitenav {
  -webkit-backdrop-filter: none;
  backdrop-filter: none;
  background: color-mix(in srgb, var(--color-bg-base) 94%, transparent);
}
/* 顶部流光：品牌色细线缓缓扫过，作为色彩区块装饰 */
.sitenav::after {
  content: '';
  position: absolute;
  left: 14px;
  right: 14px;
  top: 3px;
  height: 2px;
  border-radius: 99px;
  background: linear-gradient(
    90deg,
    transparent,
    color-mix(in srgb, var(--color-accent) 85%, transparent),
    transparent
  );
  background-size: 50% 100%;
  background-repeat: no-repeat;
  opacity: 0.75;
  pointer-events: none;
  animation: navSheen 3.6s linear infinite;
}
@keyframes navSheen {
  0% {
    background-position: -60% 0;
  }
  100% {
    background-position: 160% 0;
  }
}
.brand {
  border: none;
  background: transparent;
  cursor: pointer;
  font-weight: 700;
  font-size: 1rem;
  line-height: 1;
  color: var(--color-text-base);
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  transition: color 0.2s ease;
}
.brand::before {
  content: '';
  width: 0.55rem;
  height: 0.55rem;
  border-radius: 50%;
  background: var(--color-accent);
  box-shadow: 0 0 0 4px color-mix(in srgb, var(--color-accent) 30%, transparent);
}
.brand:hover {
  color: var(--color-link);
}

.dots {
  position: relative;
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0 0.1rem;
}

/* 进度轨道：连接各步骤圆点，填充比例随当前页推进 */
.track {
  position: absolute;
  left: 15px;
  right: 15px;
  top: 50%;
  height: 2px;
  transform: translateY(-50%);
  border-radius: 2px;
  background: color-mix(in srgb, var(--color-border) 80%, transparent);
  overflow: hidden;
  z-index: 0;
}
.track-fill {
  display: block;
  height: 100%;
  width: 0;
  border-radius: 2px;
  background: linear-gradient(
    90deg,
    var(--color-accent),
    var(--color-accent-hover)
  );
  box-shadow: 0 0 8px color-mix(in srgb, var(--color-accent) 55%, transparent);
  transition: width 0.5s var(--ease-standard);
}

.dot {
  position: relative;
  z-index: 1;
  width: 30px;
  height: 30px;
  border-radius: 50%;
  cursor: pointer;
  border: 1px solid var(--color-border);
  background: var(--color-bg-surface);
  color: var(--color-text-muted);
  display: grid;
  place-items: center;
  transition: background 0.25s var(--ease-standard),
    color 0.25s var(--ease-standard), transform 0.25s var(--ease-standard),
    border-color 0.25s var(--ease-standard);
}
.dot-ico {
  width: 16px;
  height: 16px;
  stroke: currentColor;
}
.dot:hover {
  border-color: var(--color-accent);
  color: var(--color-link);
}
.dot.active {
  background: var(--color-accent);
  color: var(--color-text-on-accent);
  border-color: transparent;
  transform: scale(1.08);
}
.dot.done {
  color: var(--color-link);
}

.actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.navbtn {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  border: 1px solid var(--color-border);
  background: var(--color-bg-surface);
  color: var(--color-text-on-surface);
  border-radius: 999px;
  padding: 0.5rem 1rem;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s ease, transform 0.2s ease, border-color 0.2s ease,
    box-shadow 0.2s ease, color 0.2s ease;
}
.navbtn:hover:not(:disabled) {
  border-color: var(--color-accent);
  color: var(--color-text-base);
  transform: translateY(-1px);
}
.navbtn:disabled {
  color: var(--color-text-disabled);
  opacity: 0.65;
  cursor: not-allowed;
}

/* 主导航按钮（下一步）：放大 + 渐变 + 发光描边 + 运动箭头图形 */
.navbtn--primary {
  background: linear-gradient(
    135deg,
    var(--color-accent),
    var(--color-accent-hover)
  );
  color: var(--color-text-on-accent);
  border-color: transparent;
  padding: 0.72rem 1.5rem;
  font-size: 1rem;
  font-weight: 700;
  letter-spacing: 0.02em;
  box-shadow: 0 10px 26px color-mix(in srgb, var(--color-accent) 35%, transparent);
}
.navbtn--primary:hover:not(:disabled) {
  border-color: transparent;
  color: var(--color-text-on-accent);
  transform: translateY(-2px);
  box-shadow: 0 14px 34px color-mix(in srgb, var(--color-accent) 55%, transparent);
}

/* 箭头图形：随悬停滑动，增强「前进 / 后退」语义 */
.ico {
  width: 1.05em;
  height: 1.05em;
  flex: none;
  transition: transform 0.28s var(--ease-standard);
}
.navbtn--primary .ico-next {
  margin-left: 0.15rem;
}
.navbtn--primary:hover:not(:disabled) .ico-next {
  transform: translateX(5px);
}
.navbtn:not(.navbtn--primary) .ico-prev {
  margin-right: 0.1rem;
}
.navbtn:not(.navbtn--primary):hover:not(:disabled) .ico-prev {
  transform: translateX(-5px);
}

@media (max-width: 560px) {
  .sitenav {
    gap: 0.5rem;
    padding: 0.45rem 0.55rem;
  }
  .navbtn {
    font-size: 0.82rem;
    padding: 0.45rem 0.72rem;
  }
  .navbtn--primary {
    font-size: 0.92rem;
    padding: 0.6rem 1.1rem;
  }
  .dot {
    width: 26px;
    height: 26px;
    font-size: 0.72rem;
  }
  .track {
    left: 13px;
    right: 13px;
  }
}
@media (prefers-reduced-motion: reduce) {
  .brand,
  .dot,
  .navbtn,
  .ico,
  .track-fill {
    transition: none;
  }
  .sitenav::after {
    animation: none;
  }
  .navbtn--primary:hover:not(:disabled) .ico-next,
  .navbtn:not(.navbtn--primary):hover:not(:disabled) .ico-prev {
    transform: none;
  }
}
</style>
