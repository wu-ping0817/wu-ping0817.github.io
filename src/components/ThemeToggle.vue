<script setup>
import { useThemeStore } from '@/stores/theme'

const theme = useThemeStore()
</script>

<template>
  <button
    class="theme-toggle"
    type="button"
    :aria-label="
      theme.current === 'light' ? '切换到暗色主题' : '切换到亮色主题'
    "
    @click="theme.toggle()"
  >
    <!-- 亮色时显示月亮（点击去暗色） -->
    <svg
      v-if="theme.current === 'light'"
      viewBox="0 0 24 24"
      width="18"
      height="18"
      fill="currentColor"
      aria-hidden="true"
    >
      <path
        d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"
      />
    </svg>
    <!-- 暗色时显示太阳（点击去亮色） -->
    <svg
      v-else
      viewBox="0 0 24 24"
      width="18"
      height="18"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
    </svg>
    <span>{{ theme.current === 'light' ? '暗色' : '亮色' }}</span>
  </button>
</template>

<style scoped>
.theme-toggle {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.45rem 0.8rem;
  border-radius: 999px;
  border: 1px solid var(--color-border);
  background: var(--color-bg-surface);
  color: var(--color-text-on-surface);
  font-size: 0.85rem;
  transition: background 0.2s ease, transform 0.2s ease;
}
.theme-toggle:hover {
  background: var(--color-accent-hover);
  color: var(--color-text-on-accent);
  transform: translateY(-1px);
}
</style>
