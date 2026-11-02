<script setup>
import { computed, ref, watch } from 'vue'

// 路由切换过渡装饰层：在「离开旧页 → 进入新页」的间隙播放，
// 用非文字视觉元素增强切换区域的视觉表现力——
//   ① 品牌色面板斜向扫过（色彩区块）
//   ② 几何图形漂浮旋转（图形装饰）
//   ③ 进度环 + 目标页图标（进度指示器 + 图标）
// 全程 pointer-events:none，不拦截交互；主题化；尊重 reduced-motion。
const props = defineProps({
  visible: { type: Boolean, default: false },
  target: { type: String, default: '' },
})

// 各页面对应的图标路径（与 SiteNav 保持一致，统一视觉语言）
const ICONS = {
  home: 'M3 11.5 12 4l9 7.5M5.5 10v9.5h13V10',
  about:
    'M12 12.5a3.8 3.8 0 100-7.6 3.8 3.8 0 000 7.6zM4.5 20a7.5 7.5 0 0115 0',
  portfolio:
    'M4 7l8-3.2L20 7l-8 3.2L4 7zm0 5l8 3.2 8-3.2M4 17l8 3.2 8-3.2',
  contact: 'M4 6.5h16v11H4zM4.5 7.5 12 12l7.5-4.5',
}
const LABELS = {
  home: '首页',
  about: '关于我',
  portfolio: '作品',
  contact: '联系',
}

const icon = computed(() => ICONS[props.target] || ICONS.home)
const label = computed(() => LABELS[props.target] || '')

// 每次显隐切换都递增 playId，强制内层重挂载以重放 CSS 动画
const playId = ref(0)
watch(
  () => props.visible,
  (v) => {
    if (v) playId.value++
  }
)
</script>

<template>
  <div class="routefx" :class="{ 'is-on': visible }" aria-hidden="true">
    <div class="rf-inner" :key="playId">
      <!-- 色彩区块：斜向扫过的品牌色面板 -->
      <span class="rf-panel rf-panel--1"></span>
      <span class="rf-panel rf-panel--2"></span>
      <span class="rf-panel rf-panel--3"></span>

      <!-- 图形装饰：几何形状 -->
      <span class="rf-shape rf-shape--ring"></span>
      <span class="rf-shape rf-shape--circle"></span>
      <span class="rf-shape rf-shape--tri"></span>
      <span class="rf-shape rf-shape--dot"></span>

      <!-- 进度指示器 + 目标页图标 -->
      <div class="rf-badge">
        <svg class="rf-ring" viewBox="0 0 80 80">
          <circle class="rf-ring-track" cx="40" cy="40" r="34" />
          <circle class="rf-ring-fill" cx="40" cy="40" r="34" />
        </svg>
        <svg class="rf-ico" viewBox="0 0 24 24">
          <path
            :d="icon"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </div>
      <span class="rf-tip">{{ label }}</span>
    </div>
  </div>
</template>

<style scoped>
.routefx {
  position: fixed;
  inset: 0;
  z-index: 40; /* 位于页面内容之上、底部导航(50)之下，互不遮挡 */
  pointer-events: none; /* 永远不拦截交互 */
  opacity: 0;
  transition: opacity 0.35s ease;
  display: grid;
  place-items: center;
  overflow: hidden;
}
.routefx.is-on {
  opacity: 1;
}

.rf-inner {
  position: relative;
  width: 100%;
  height: 100%;
  /* 隔离重绘：装饰层内部的变化不触发外部（含导航玻璃）重排 */
  contain: layout paint style;
}

/* ---------- 色彩区块：斜向扫过的品牌色面板 ----------
   性能关键：不使用 filter:blur（移动时逐帧重栅格化，是卡顿主因），
   改用「透明端渐变」获得柔光质感；translate3d + will-change 提升到合成层。 */
.rf-panel {
  position: absolute;
  top: -25%;
  height: 150%;
  width: 46%;
  border-radius: 36px;
  opacity: 0;
  will-change: transform;
  transform: translate3d(0, 0, 0);
  backface-visibility: hidden;
}
.rf-panel--1 {
  left: 0;
  background: linear-gradient(
    120deg,
    transparent,
    color-mix(in srgb, var(--color-accent) 50%, transparent),
    transparent
  );
  animation: rfSweep 1.5s cubic-bezier(0.16, 1, 0.3, 1) both;
}
.rf-panel--2 {
  left: 27%;
  background: linear-gradient(
    120deg,
    transparent,
    color-mix(in srgb, var(--color-brand-secondary, #b6d4f6) 42%, transparent),
    transparent
  );
  animation: rfSweep 1.5s cubic-bezier(0.16, 1, 0.3, 1) 0.18s both;
}
.rf-panel--3 {
  left: 54%;
  background: linear-gradient(
    120deg,
    transparent,
    color-mix(in srgb, var(--color-accent-hover) 46%, transparent),
    transparent
  );
  animation: rfSweep 1.5s cubic-bezier(0.16, 1, 0.3, 1) 0.36s both;
}
@keyframes rfSweep {
  0% {
    transform: translate3d(-130%, 0, 0) rotate(9deg);
    opacity: 0;
  }
  18% {
    opacity: 0.5;
  }
  100% {
    transform: translate3d(330%, 0, 0) rotate(9deg);
    opacity: 0;
  }
}

/* ---------- 图形装饰：几何形状 ---------- */
.rf-shape {
  position: absolute;
  will-change: transform, opacity;
  opacity: 0;
}
.rf-shape--ring {
  width: 120px;
  height: 120px;
  left: 12%;
  top: 22%;
  border: 2px solid color-mix(in srgb, var(--color-accent) 60%, transparent);
  border-radius: 50%;
  animation: rfFloat 1.6s ease-in-out 0.1s both, rfSpin 4s linear both;
}
.rf-shape--circle {
  width: 64px;
  height: 64px;
  right: 14%;
  top: 30%;
  border-radius: 50%;
  background: radial-gradient(
    circle at 35% 35%,
    color-mix(in srgb, var(--color-accent) 55%, transparent),
    transparent 70%
  );
  animation: rfFloat 1.8s ease-in-out 0.25s both;
}
.rf-shape--tri {
  width: 0;
  height: 0;
  right: 22%;
  bottom: 24%;
  border-left: 26px solid transparent;
  border-right: 26px solid transparent;
  border-bottom: 44px solid
    color-mix(in srgb, var(--color-accent-hover) 40%, transparent);
  animation: rfFloat 2s ease-in-out 0.4s both, rfSpin 6s linear both;
}
.rf-shape--dot {
  width: 14px;
  height: 14px;
  left: 26%;
  bottom: 28%;
  border-radius: 50%;
  background: color-mix(in srgb, var(--color-accent) 70%, transparent);
  animation: rfFloat 1.4s ease-in-out 0.15s both;
}
@keyframes rfFloat {
  0% {
    opacity: 0;
    transform: translate3d(0, 14px, 0) scale(0.85);
  }
  35% {
    opacity: 0.9;
  }
  100% {
    opacity: 0;
    transform: translate3d(0, -22px, 0) scale(1.05);
  }
}
@keyframes rfSpin {
  to {
    transform: rotate(360deg);
  }
}

/* ---------- 进度指示器 + 目标页图标 ---------- */
.rf-badge {
  position: absolute;
  left: 50%;
  top: 50%;
  width: 84px;
  height: 84px;
  transform: translate3d(-50%, -50%, 0) scale(0.8);
  display: grid;
  place-items: center;
  opacity: 0;
  /* 轻量、静态光晕（不随动画重栅格），替代原 drop-shadow 滤镜 */
  filter: drop-shadow(0 0 10px color-mix(in srgb, var(--color-accent) 35%, transparent));
  will-change: transform, opacity;
  animation: rfBadge 1.5s cubic-bezier(0.16, 1, 0.3, 1) both;
}
@keyframes rfBadge {
  0% {
    opacity: 0;
    transform: translate3d(-50%, -50%, 0) scale(0.7);
  }
  30% {
    opacity: 1;
    transform: translate3d(-50%, -50%, 0) scale(1);
  }
  100% {
    opacity: 0;
    transform: translate3d(-50%, -50%, 0) scale(1.04);
  }
}
.rf-ring {
  position: absolute;
  inset: 0;
  width: 84px;
  height: 84px;
  transform: rotate(-90deg);
}
.rf-ring-track {
  fill: none;
  stroke: color-mix(in srgb, var(--color-border) 85%, transparent);
  stroke-width: 5;
}
.rf-ring-fill {
  fill: none;
  stroke: var(--color-accent);
  stroke-width: 5;
  stroke-linecap: round;
  stroke-dasharray: 214;
  stroke-dashoffset: 214;
  /* 不用 drop-shadow 滤镜（移动/描边动画时逐帧重栅格），改由 .rf-badge 的轻量 box-shadow 提供光晕 */
  animation: rfRing 1.4s cubic-bezier(0.16, 1, 0.3, 1) forwards;
}
@keyframes rfRing {
  to {
    stroke-dashoffset: 0;
  }
}
.rf-ico {
  position: relative;
  width: 34px;
  height: 34px;
  color: var(--color-accent);
}

.rf-tip {
  position: absolute;
  left: 50%;
  top: calc(50% + 64px);
  transform: translateX(-50%);
  font-size: 0.9rem;
  font-weight: 600;
  letter-spacing: 0.12em;
  color: var(--color-text-muted);
  opacity: 0;
  animation: rfTip 1.5s ease both;
}
@keyframes rfTip {
  0%,
  25% {
    opacity: 0;
    transform: translate(-50%, 8px);
  }
  55%,
  85% {
    opacity: 1;
    transform: translate(-50%, 0);
  }
  100% {
    opacity: 0;
    transform: translate(-50%, -4px);
  }
}

/* ---------- 动效降级：reduced-motion 下仅做极简淡入淡出 ---------- */
@media (prefers-reduced-motion: reduce) {
  .rf-panel,
  .rf-shape,
  .rf-badge,
  .rf-tip {
    animation: none !important;
    opacity: 0 !important;
  }
  .rf-ring-fill {
    stroke-dashoffset: 0;
    animation: none !important;
  }
}
</style>
