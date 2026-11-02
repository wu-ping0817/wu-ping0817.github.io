<script setup>
/**
 * Hobbies.vue —— 自包含的「爱好」展示模块。
 *
 * 设计目标（对应重写要求）：
 *  1) 保留原有核心功能与数据展示逻辑：卡片列表、点击就地展开详情（desc 常驻 + detail 展开）、
 *     悬停上浮、占位项；卡片自身样式不受任何动效影响；
 *  2) 独立样式作用域与命名空间（hb-*）：<style scoped> 自动加 data-v 属性，类前缀 hb-，
 *     不与 layout / main / section 下其它 block 发生 CSS 或 DOM 事件冲突；
 *  3) 不依赖、不修改任何页面全局变量或其他模块内部状态：数据经 props 传入，自身管理
 *     expanded 状态、入场观察器，全部在组件内闭环；
 *  4) 可独立渲染：自带入场显现（本地 IntersectionObserver，不依赖父级 v-reveal-group）。
 *
 * 边界清晰、无副作用：挂载时创建资源、卸载时（观察器）释放。
 */
import { ref, onMounted, onBeforeUnmount } from 'vue'

const props = defineProps({
  // 爱好数据数组：[{ label, desc, detail }, ...]
  items: { type: Array, required: true },
  title: { type: String, default: '藏起来的一点喜欢' },
  placeholderText: { type: String, default: '＋ 我的隐藏爱好，等你来挖' },
})

/* ===================== 1) 内部状态：仅本模块使用 ===================== */
const expanded = ref(new Set())
const isOpen = (label) => expanded.value.has(label)
function toggle(label) {
  const next = new Set(expanded.value)
  next.has(label) ? next.delete(label) : next.add(label)
  expanded.value = next
}

/* ===================== 2) 入场显现：本地观察器，可独立渲染 ===================== */
const rootEl = ref(null)
const revealed = ref(false)
let io = null

function onToggle(h) {
  toggle(h.label)
}

/* ===================== 生命周期：资源创建与释放 ===================== */
onMounted(() => {
  const reduce =
    window.matchMedia &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  if (reduce || !('IntersectionObserver' in window)) {
    revealed.value = true
  } else {
    io = new IntersectionObserver(
      (entries) => {
        entries.forEach((en) => {
          if (en.isIntersecting) {
            revealed.value = true
            io.disconnect()
          }
        })
      },
      { threshold: 0.15 }
    )
    if (rootEl.value) io.observe(rootEl.value)
  }
  // 兜底：极端情况下观察器未触发，1.6s 后强制显示，绝不永久隐藏
  setTimeout(() => {
    revealed.value = true
  }, 1600)
})
onBeforeUnmount(() => {
  io?.disconnect()
})
</script>

<template>
  <div ref="rootEl" class="hb-root" :class="{ 'hb-in': revealed }">
    <h3 class="hb-title hb-reveal" :style="{ transitionDelay: '0s' }">
      {{ title }}
    </h3>

    <ul class="hb-list">
      <li
        v-for="(h, i) in items"
        :key="h.label"
        class="hb-card"
        :class="{ 'hb-card--open': isOpen(h.label) }"
      >
        <div
          class="hb-reveal"
          :style="{ transitionDelay: (i + 1) * 0.12 + 's' }"
        >
          <button
            class="hb-toggle"
            type="button"
            data-fx="random"
            :aria-expanded="isOpen(h.label)"
            @click="onToggle(h, $event)"
          >
            <span class="hb-label">{{ h.label }}</span>
            <span class="hb-chev" aria-hidden="true">⌄</span>
          </button>
          <div class="hb-body">
            <p class="hb-desc">{{ h.desc }}</p>
            <div
              class="hb-detail"
              :class="{ 'hb-detail--open': isOpen(h.label) }"
            >
              <p>{{ h.detail }}</p>
            </div>
          </div>
        </div>
      </li>

      <!-- 结构占位：后续补充爱好的预留空白项 -->
      <li class="hb-card hb-card--placeholder" aria-hidden="true">
        <span class="hb-reveal hb-label">{{ placeholderText }}</span>
      </li>
    </ul>
  </div>
</template>

<style scoped>
.hb-root {
  position: relative;
  margin-bottom: 2.5rem;
}
.hb-title {
  margin: 0 0 1rem;
  font-size: 1.2rem;
}

.hb-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0.8rem;
  max-width: 640px;
}

/* 入场显现（组件自包含，不依赖父级 reveal-group） */
.hb-reveal {
  opacity: 0;
  transform: translateX(-60px) scale(0.98);
  transition: opacity 0.62s cubic-bezier(0.22, 0.61, 0.36, 1),
    transform 0.62s cubic-bezier(0.22, 0.61, 0.36, 1);
  will-change: opacity, transform;
}
.hb-in .hb-reveal {
  opacity: 1;
  transform: none;
}

/* 卡片：仅负责悬停上浮/缩放与边框发光 */
.hb-card {
  padding: 0.95rem 1.1rem;
  border-radius: 14px;
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  transition: transform 0.28s cubic-bezier(0.22, 0.61, 0.36, 1),
    box-shadow 0.28s ease, border-color 0.28s ease;
}
.hb-card:hover {
  transform: translateY(-9px) scale(1.025);
  border-color: color-mix(
    in srgb,
    var(--color-accent, #3b82f6) 55%,
    var(--color-border)
  );
  box-shadow: 0 14px 34px
    color-mix(in srgb, var(--color-accent, #3b82f6) 18%, transparent);
}

.hb-toggle {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  padding: 0;
  margin: 0;
  border: none;
  background: transparent;
  font: inherit;
  text-align: left;
  cursor: pointer;
  color: inherit;
}
.hb-label {
  font-weight: 600;
  font-size: 1rem;
  color: var(--color-accent-strong, var(--color-accent));
}
.hb-chev {
  font-size: 1.2rem;
  line-height: 1;
  color: var(--color-text-muted);
  transition: transform 0.3s cubic-bezier(0.22, 0.61, 0.36, 1);
}
.hb-card--open .hb-chev {
  transform: rotate(180deg);
}

.hb-desc {
  margin: 0.5rem 0 0;
  line-height: 1.6;
  font-size: 0.92rem;
  opacity: 0.85;
}
/* 点击展开：max-height + opacity 过渡 */
.hb-detail {
  max-height: 0;
  opacity: 0;
  overflow: hidden;
  transition: max-height 0.4s cubic-bezier(0.22, 0.61, 0.36, 1), opacity 0.35s ease;
}
.hb-detail--open {
  max-height: 240px;
  opacity: 1;
}
.hb-detail p {
  margin: 0.6rem 0 0;
  font-size: 0.9rem;
  line-height: 1.65;
  opacity: 0.9;
}

/* 占位项：流动虚线 + 上浮，不参与悬停抬升 */
.hb-card--placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px dashed var(--color-border);
  background: repeating-linear-gradient(
    90deg,
    transparent,
    transparent 6px,
    color-mix(in srgb, var(--color-accent, #3b82f6) 22%, transparent) 6px,
    color-mix(in srgb, var(--color-accent, #3b82f6) 22%, transparent) 12px
  );
  color: var(--color-text-muted);
  font-size: 0.88rem;
  opacity: 0.8;
  cursor: default;
}
.hb-card--placeholder:hover {
  transform: none;
  box-shadow: none;
  border-color: var(--color-border);
}

/* 减少动效：关闭一切过渡与入场位移 */
@media (prefers-reduced-motion: reduce) {
  .hb-reveal,
  .hb-card,
  .hb-detail,
  .hb-chev {
    transition: none !important;
    animation: none !important;
  }
  .hb-reveal {
    opacity: 1;
    transform: none;
  }
}
</style>
