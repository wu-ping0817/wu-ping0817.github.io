<script setup>
import { onMounted, onBeforeUnmount } from 'vue'

/**
 * VideoModal：作品演示视频弹层播放器。
 * - 由卡片/详情的「▶ 演示」按钮触发；v-if 卸载即销毁 <video>，自动停止播放与声音；
 * - Esc / 点击遮罩 / ✕ 三种方式关闭；
 * - 不强制 16:9 裁切：video 保持原始宽高比，仅限制最大高度（72vh）防溢出。
 */
const props = defineProps({
  open: Boolean,
  title: String,
  src: String,
})
const emit = defineEmits(['close'])

function onKey(e) {
  if (e.key === 'Escape' && props.open) emit('close')
}
onMounted(() => window.addEventListener('keydown', onKey))
onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <Teleport to="body">
    <div v-if="open" class="vm-mask" @click.self="emit('close')">
      <div class="vm-panel" role="dialog" aria-modal="true" :aria-label="`演示视频：${title}`">
        <header class="vm-head">
          <span class="vm-title">演示 · {{ title }}</span>
          <button class="vm-close" type="button" aria-label="关闭" @click="emit('close')">
            ✕
          </button>
        </header>
        <video
          v-if="src"
          class="vm-video"
          :src="src"
          controls
          autoplay
          playsinline
          preload="metadata"
        ></video>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.vm-mask {
  position: fixed;
  inset: 0;
  z-index: 60;
  display: grid;
  place-items: center;
  padding: 1.2rem;
  background: rgba(6, 11, 22, 0.72);
  backdrop-filter: blur(6px);
  animation: vmFade 0.18s ease both;
}
.vm-panel {
  width: min(880px, 100%);
  border-radius: 16px;
  overflow: hidden;
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  box-shadow: 0 30px 80px -24px rgba(0, 0, 0, 0.75);
  animation: vmPop 0.22s cubic-bezier(0.16, 1, 0.3, 1) both;
}
.vm-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.8rem;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--color-border);
}
.vm-title {
  font-size: 0.9rem;
  font-weight: 700;
  color: var(--color-text-on-surface);
  min-width: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.vm-close {
  flex: none;
  width: 30px;
  height: 30px;
  border-radius: 8px;
  border: 1px solid var(--color-border);
  background: var(--color-bg-elevated);
  color: var(--color-text-on-surface);
  cursor: pointer;
  font-size: 0.9rem;
}
.vm-close:hover {
  color: var(--color-error, #ff8e8e);
}
.vm-video {
  display: block;
  width: 100%;
  max-height: 72vh;
  background: #000;
}
@keyframes vmFade {
  from { opacity: 0; }
  to { opacity: 1; }
}
@keyframes vmPop {
  from { opacity: 0; transform: translateY(14px) scale(0.98); }
  to { opacity: 1; transform: none; }
}
@media (prefers-reduced-motion: reduce) {
  .vm-mask,
  .vm-panel {
    animation: none;
  }
}
</style>
