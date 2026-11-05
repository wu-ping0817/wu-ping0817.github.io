<script setup>
import { ref, onBeforeUnmount } from 'vue'
import { useContent } from '@/composables/useContent'
import ImageSlot from '@/components/ImageSlot.vue'

const { profile } = useContent()

// —— 减少动效偏好：统一降级（关闭倾斜）——
const reduceMotion =
  typeof window !== 'undefined' &&
  window.matchMedia &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches

/* ============ 头像指针跟随 3D 倾斜（悬停触发） ============ */
const avatarEl = ref(null)
let tiltRaf = 0
function onAvatarMove(e) {
  const el = avatarEl.value
  if (!el || reduceMotion) return
  const r = el.getBoundingClientRect()
  const px = (e.clientX - r.left) / r.width - 0.5
  const py = (e.clientY - r.top) / r.height - 0.5
  if (tiltRaf) cancelAnimationFrame(tiltRaf)
  tiltRaf = requestAnimationFrame(() => {
    el.style.setProperty('--ay', (px * 14).toFixed(2) + 'deg')
    el.style.setProperty('--ax', (py * -12).toFixed(2) + 'deg')
  })
}
function onAvatarLeave() {
  const el = avatarEl.value
  if (!el) return
  el.style.setProperty('--ax', '0deg')
  el.style.setProperty('--ay', '0deg')
}

/* ============ 页内「此刻的我」状态切换（手动触发，无自动循环） ============ */
const moods = [
  '我现在正在做推文',
  '我现在正在打游戏',
  '我现在正在做测试',
]
const moodIdx = ref(0)
function goMood(i) {
  moodIdx.value = (i + moods.length) % moods.length
}
function nextMood() {
  goMood(moodIdx.value + 1)
}
function prevMood() {
  goMood(moodIdx.value - 1)
}

onBeforeUnmount(() => {
  if (tiltRaf) cancelAnimationFrame(tiltRaf)
})
</script>

<template>
  <section class="screen about">
    <div class="intro">
      <div
        ref="avatarEl"
        class="avatar-wrap"
        @mousemove="onAvatarMove"
        @mouseleave="onAvatarLeave"
      >
        <ImageSlot
          class="avatar"
          src="img/avatar.webp"
          alt="头像"
          :title="profile.name"
          variant="photo"
          ratio="1 / 1"
          round
        />
      </div>
      <div class="id">
        <h2 class="name">{{ profile.name }}</h2>
        <p class="role">{{ profile.title }}</p>
        <p class="bio">{{ profile.bio }}</p>
      </div>
    </div>

    <!-- 页内状态切换：「此刻的我」（点击圆点·上下项·文字切换；无自动循环） -->
    <div class="mood">
      <span class="mood-label"
        ><i class="live-dot" aria-hidden="true"></i>状态：</span
      >
      <div
        class="mood-stage"
        role="button"
        data-fx="ripple"
        tabindex="0"
        :aria-label="'当前状态：' + moods[moodIdx] + '，点击切换下一条'"
        @click="nextMood"
        @keydown.enter.prevent="nextMood"
        @keydown.space.prevent="nextMood"
      >
        <Transition name="mood" mode="out-in">
          <p class="mood-text" :key="moodIdx">{{ moods[moodIdx] }}</p>
        </Transition>
      </div>
      <div class="mood-controls">
        <button
          class="mood-nav"
          type="button"
          aria-label="上一条"
          data-fx="shadow"
          @click="prevMood"
        >
          ‹
        </button>
        <div class="mood-dots" role="tablist" aria-label="当前状态">
          <button
            v-for="(m, i) in moods"
            :key="i"
            class="mood-dot"
            :class="{ active: i === moodIdx }"
            data-fx="color"
            type="button"
            role="tab"
            :aria-selected="i === moodIdx"
            :aria-label="'状态 ' + (i + 1)"
            @click="goMood(i)"
          ></button>
        </div>
        <button
          class="mood-nav"
          type="button"
          aria-label="下一条"
          data-fx="bounce"
          @click="nextMood"
        >
          ›
        </button>
      </div>
    </div>

    <!-- 最近打算做的 -->
    <div class="plans">
      <span class="mood-label"
        ><i class="live-dot" aria-hidden="true"></i>最近打算做的</span
      >
      <ul class="plans-list">
        <li class="plans-item">游戏没有中文实在难受</li>
      </ul>
    </div>
  </section>
</template>

<style scoped>
.about {
  text-align: left;
}

.intro {
  display: flex;
  gap: 1.25rem;
  align-items: center;
  margin-bottom: 1.4rem;
}
.avatar-wrap {
  flex: none;
  width: 84px;
  height: 84px;
  transform: perspective(520px) rotateX(var(--ax, 0deg)) rotateY(var(--ay, 0deg));
  transform-style: preserve-3d;
  transition: transform 0.35s cubic-bezier(0.22, 0.61, 0.36, 1);
  will-change: transform;
}
.avatar-wrap:hover {
  transform: perspective(520px) rotateX(var(--ax, 0deg)) rotateY(var(--ay, 0deg))
    scale(1.04);
}
.avatar {
  width: 100%;
  height: 100%;
}
.name {
  margin: 0;
  font-size: 1.4rem;
}
.role {
  margin: 0.2rem 0 0.3rem;
  color: var(--color-text-muted);
}
.bio {
  margin: 0.25rem 0 0;
  max-width: 46ch;
  font-size: 0.9rem;
  line-height: 1.65;
  color: var(--color-text-muted);
  opacity: 0.82;
}

/* ---------- 页内轮播：「此刻的我」 ---------- */
.mood {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  margin: 0 0 1.6rem;
  padding: 1rem 1.15rem;
  border-radius: 16px;
  max-width: 640px;
  background: color-mix(in srgb, var(--color-accent, #3b82f6) 7%, var(--color-bg-surface));
  border: 1px solid var(--color-border);
}
.mood-label {
  font-size: 0.74rem;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}
.live-dot {
  display: inline-block;
  width: 7px;
  height: 7px;
  margin-right: 0.4rem;
  border-radius: 50%;
  background: var(--color-accent, #3b82f6);
  vertical-align: middle;
  animation: breathe 1.6s ease-in-out infinite;
}
@keyframes breathe {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.3;
  }
}
.mood-stage {
  position: relative;
  min-height: 1.9em;
  cursor: pointer;
  outline: none;
}
.mood-stage:focus-visible {
  box-shadow: 0 0 0 3px
    color-mix(in srgb, var(--color-accent, #3b82f6) 40%, transparent);
  border-radius: 8px;
}
.mood-text {
  margin: 0;
  font-size: 1.02rem;
  font-weight: 600;
  line-height: 1.6;
}
.mood-enter-active,
.mood-leave-active {
  transition: opacity 0.45s ease, transform 0.45s ease;
}
.mood-enter-from {
  opacity: 0;
  transform: translateX(36px);
}
.mood-leave-to {
  opacity: 0;
  transform: translateX(-36px);
}
.mood-dots {
  display: flex;
  gap: 0.4rem;
  margin-top: 0.2rem;
}
.mood-controls {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  margin-top: 0.4rem;
}
.mood-nav {
  width: 26px;
  height: 26px;
  flex: none;
  padding: 0;
  border: 1px solid var(--color-border);
  border-radius: 50%;
  background: var(--color-bg-surface);
  color: var(--color-text);
  font-size: 1.1rem;
  line-height: 1;
  cursor: pointer;
  transition: background 0.2s ease, transform 0.15s ease, border-color 0.2s ease;
}
.mood-nav:hover {
  background: color-mix(in srgb, var(--color-accent, #3b82f6) 16%, transparent);
  border-color: color-mix(in srgb, var(--color-accent, #3b82f6) 45%, var(--color-border));
}
.mood-nav:active {
  transform: scale(0.92);
}
.mood-dot {
  width: 7px;
  height: 7px;
  padding: 0;
  border: none;
  border-radius: 50%;
  background: var(--color-border);
  cursor: pointer;
  transition: background 0.2s ease, transform 0.2s ease;
}
.mood-dot.active {
  background: var(--color-accent, #3b82f6);
  transform: scale(1.3);
}

/* ---------- 最近打算做的 ---------- */
.plans {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  margin: 0 0 1.6rem;
  padding: 1rem 1.15rem;
  border-radius: 16px;
  max-width: 640px;
  background: color-mix(in srgb, var(--color-accent, #3b82f6) 7%, var(--color-bg-surface));
  border: 1px solid var(--color-border);
}
.plans-list {
  list-style: none;
  margin: 0.5rem 0 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}
.plans-item {
  position: relative;
  padding-left: 1.1rem;
  font-size: 1.02rem;
  line-height: 1.6;
  color: var(--color-text);
}
.plans-item::before {
  content: '';
  position: absolute;
  left: 0;
  top: 0.62em;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--color-accent, #3b82f6);
}

@media (prefers-reduced-motion: reduce) {
  .avatar-wrap,
  .mood-text,
  .mood-dot,
  .live-dot {
    transition: none !important;
    animation: none !important;
  }
}
</style>
