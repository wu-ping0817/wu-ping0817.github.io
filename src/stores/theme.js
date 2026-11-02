import { defineStore } from 'pinia'

const STORAGE_KEY = 'person-show-theme'

export const useThemeStore = defineStore('theme', {
  state: () => ({
    current: 'dark', // 'light' | 'dark'（默认暗色，贴合站点视觉基调）
  }),
  actions: {
    init() {
      const saved = localStorage.getItem(STORAGE_KEY)
      const prefersDark = window.matchMedia?.(
        '(prefers-color-scheme: dark)'
      ).matches
      // 默认暗色；仅当用户在 localStorage 中显式保存过偏好时才覆盖
      this.current = saved || (prefersDark ? 'dark' : 'dark')
      this.apply()
    },
    toggle() {
      this.current = this.current === 'light' ? 'dark' : 'light'
      this.apply()
    },
    apply() {
      document.documentElement.dataset.theme = this.current
      localStorage.setItem(STORAGE_KEY, this.current)
    },
  },
})
