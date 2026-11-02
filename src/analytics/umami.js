import { siteConfig } from '@/config'

// 纯前端访问统计：仅在配置开启时注入 Umami 脚本，否则完全无副作用。
export function initAnalytics() {
  const u = siteConfig.analytics.umami
  if (!u.enabled || !u.src || !u.id || u.id === 'YOUR_UMAMI_ID') return
  const s = document.createElement('script')
  s.async = true
  s.defer = true
  s.src = u.src
  s.setAttribute('data-website-id', u.id)
  document.head.appendChild(s)
}
