/**
 * v-reveal 指令：元素进入视口时添加 .is-visible，触发渐显/上移动效。
 * 支持：<div v-reveal> 或 <div v-reveal data-reveal-delay="120">（错峰延迟，单位 ms）
 * 尊重 prefers-reduced-motion：降级为直接显示。
 */
export const reveal = {
  mounted(el) {
    const reduce = window.matchMedia?.(
      '(prefers-reduced-motion: reduce)'
    ).matches
    if (reduce) {
      el.classList.add('is-visible')
      return
    }
    el.classList.add('reveal-init')
    const delay = Number(el.dataset.revealDelay) || 0

    // 统一的「显示」逻辑：保证元素最终一定可见，避免任何边界情况下卡在
    // opacity:0（例如 IntersectionObserver 不支持、或元素已在视口但回调未触发）。
    let revealed = false
    const revealNow = () => {
      if (revealed) return
      revealed = true
      el.classList.add('is-visible')
      observer?.disconnect()
    }

    let observer = null
    if ('IntersectionObserver' in window) {
      observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              setTimeout(revealNow, delay)
            }
          })
        },
        { threshold: 0.12, rootMargin: '0px 0px -8% 0px' }
      )
      observer.observe(el)
    } else {
      // 无 IntersectionObserver 时直接展示（带错峰延迟）
      setTimeout(revealNow, delay)
    }

    // 兜底：无论何种原因，1.2s 后强制显示，绝不让内容永久隐藏。
    setTimeout(revealNow, 1200)
    el._revealObserver = observer
  },
  unmounted(el) {
    el._revealObserver?.disconnect()
  },
}
