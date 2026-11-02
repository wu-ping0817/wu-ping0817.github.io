<script setup>
import { ref, watch, onBeforeUnmount } from 'vue'

const props = defineProps({
  open: { type: Boolean, default: false },
  title: { type: String, default: '' },
  src: { type: String, default: '' },
  lang: { type: String, default: 'bash' },
})
const emit = defineEmits(['close'])

const code = ref('')
const status = ref('idle') // idle | loading | ready | error
const copied = ref(false)
let abort = null

async function load() {
  if (!props.src) return
  status.value = 'loading'
  code.value = ''
  copied.value = false
  abort?.abort()
  abort = new AbortController()
  try {
    const res = await fetch(props.src, { signal: abort.signal })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    code.value = await res.text()
    status.value = 'ready'
  } catch (e) {
    if (e.name === 'AbortError') return
    status.value = 'error'
  }
}

watch(
  () => props.open,
  (v) => {
    if (v) load()
    else abort?.abort()
  },
  { immediate: true }
)

function close() {
  emit('close')
}
function onKey(e) {
  if (e.key === 'Escape' && props.open) close()
}
function copy() {
  if (!code.value) return
  navigator.clipboard?.writeText(code.value).then(
    () => {
      copied.value = true
      setTimeout(() => (copied.value = false), 1600)
    },
    () => {}
  )
}

// 全局 ESC 监听
if (typeof window !== 'undefined') {
  window.addEventListener('keydown', onKey)
  onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="open"
      class="cm-mask"
      @click.self="close"
    >
      <div
        class="cm-panel"
        role="dialog"
        aria-modal="true"
        :aria-label="`查看脚本：${title}`"
      >
        <header class="cm-head">
          <div class="cm-meta">
            <span class="cm-dot" />
            <span class="cm-name">{{ title || '脚本' }}</span>
            <span class="cm-lang">{{ lang }}</span>
          </div>
          <div class="cm-actions">
            <button
              type="button"
              class="cm-btn"
              :disabled="status !== 'ready'"
              @click="copy"
            >
              {{ copied ? '已复制 ✓' : '复制' }}
            </button>
            <button type="button" class="cm-btn cm-close" aria-label="关闭" @click="close">
              ✕
            </button>
          </div>
        </header>

        <div class="cm-body">
          <div v-if="status === 'loading'" class="cm-state">读取中…</div>
          <div v-else-if="status === 'error'" class="cm-state cm-err">
            脚本读取失败。请确认该文件已放入对应作品文件夹
            <code>data/works/&lt;id&gt;/</code>。
          </div>
          <pre v-else class="cm-code"><code>{{ code }}</code></pre>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.cm-mask {
  position: fixed;
  inset: 0;
  z-index: 60;
  display: grid;
  place-items: center;
  padding: 1.2rem;
  background: rgba(6, 11, 22, 0.62);
  backdrop-filter: blur(4px);
  animation: cmFade 0.18s ease both;
}
.cm-panel {
  width: min(760px, 100%);
  max-height: min(78vh, 640px);
  display: flex;
  flex-direction: column;
  border-radius: 16px;
  background: var(--color-bg-surface);
  color: var(--color-text-on-surface);
  border: 1px solid var(--color-border);
  box-shadow: 0 26px 70px -22px rgba(0, 0, 0, 0.7);
  overflow: hidden;
  animation: cmPop 0.22s cubic-bezier(0.16, 1, 0.3, 1) both;
}
.cm-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.7rem 0.9rem;
  border-bottom: 1px solid var(--color-border);
  background: var(--color-bg-elevated);
}
.cm-meta {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  min-width: 0;
}
.cm-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--color-accent);
  box-shadow: 0 0 8px color-mix(in srgb, var(--color-accent) 60%, transparent);
  flex: none;
}
.cm-name {
  font-weight: 600;
  font-size: 0.92rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cm-lang {
  font-size: 0.68rem;
  padding: 0.1rem 0.45rem;
  border-radius: 999px;
  border: 1px solid var(--color-border);
  color: var(--color-text-muted);
  flex: none;
}
.cm-actions {
  display: flex;
  gap: 0.4rem;
  flex: none;
}
.cm-btn {
  font-size: 0.8rem;
  font-weight: 600;
  padding: 0.32rem 0.7rem;
  border-radius: 8px;
  border: 1px solid var(--color-border);
  background: var(--color-bg-surface);
  color: var(--color-text-on-surface);
  cursor: pointer;
  transition: border-color 0.2s ease, color 0.2s ease, transform 0.15s ease;
}
.cm-btn:hover:not(:disabled) {
  border-color: var(--color-accent);
  color: var(--color-link);
}
.cm-btn:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}
.cm-close:hover {
  color: var(--color-error, #ff8e8e);
}
.cm-body {
  flex: 1;
  overflow: auto;
  padding: 0;
}
.cm-code {
  margin: 0;
  padding: 1rem 1.1rem;
  font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
  font-size: 0.82rem;
  line-height: 1.65;
  color: var(--color-text-on-surface);
  white-space: pre;
  tab-size: 2;
}
.cm-state {
  padding: 2.4rem 1.1rem;
  text-align: center;
  color: var(--color-text-muted);
  font-size: 0.9rem;
}
.cm-err {
  color: var(--color-error, #ff8e8e);
}
.cm-err code {
  color: var(--color-text-on-surface);
  background: var(--color-bg-elevated);
  padding: 0.05rem 0.35rem;
  border-radius: 5px;
}

@keyframes cmFade {
  from { opacity: 0; }
  to { opacity: 1; }
}
@keyframes cmPop {
  from { opacity: 0; transform: translateY(14px) scale(0.98); }
  to { opacity: 1; transform: none; }
}
@media (prefers-reduced-motion: reduce) {
  .cm-mask,
  .cm-panel {
    animation: none;
  }
}
</style>
