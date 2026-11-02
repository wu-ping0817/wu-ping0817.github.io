/**
 * v-depth：滚动联动的 3D 纵深视差（持续随滚动变化，非一次性播放）。
 *
 * 用法：
 *   <div v-depth>
 *   <div v-depth="{ amount: 60, scale: 0.08, opacity: true }">
 *
 * 行为：元素随其在视口中的滚动位置，沿 Z 轴前后位移并轻微缩放 / 淡入淡出，
 *       形成空间纵深与层次分布（居中时最近、最大、最清晰；远离时退后、缩小、淡出）。
 *       仅 transform / opacity（GPU 合成），rAF 节流，尊重 prefers-reduced-motion。
 */
export const depth = {
  mounted(el, binding) {
    const reduce = window.matchMedia?.(
      '(prefers-reduced-motion: reduce)'
    ).matches
    if (reduce) {
      el.style.opacity = '1'
      return
    }

    const o = binding.value || {}
    const amount = o.amount ?? 60 // Z 轴最大位移（px）
    const scaleAmt = o.scale ?? 0.08 // 缩放系数
    const useOpacity = o.opacity !== false

    el.style.willChange = 'transform, opacity'

    let ticking = false
    const update = () => {
      ticking = false
      const r = el.getBoundingClientRect()
      const vh = window.innerHeight || document.documentElement.clientHeight
      const center = r.top + r.height / 2
      // delta ∈ ~[-0.5, 0.5]：视口下方为负，上方为正
      const delta = center / vh - 0.5
      const z = (-delta * amount).toFixed(1) // 居中时 z 最大（最近）
      const s = (1 + -delta * scaleAmt).toFixed(3)
      const op = useOpacity
        ? Math.min(1, Math.max(0.35, 1 - Math.abs(delta) * 0.6)).toFixed(2)
        : '1'
      el.style.transform = `perspective(1000px) translateZ(${z}px) scale(${s})`
      el.style.opacity = op
    }
    const onScroll = () => {
      if (!ticking) {
        ticking = true
        requestAnimationFrame(update)
      }
    }

    update() // 首屏已在视口的元素立即算出正确外观
    window.addEventListener('scroll', onScroll, { passive: true })
    window.addEventListener('resize', onScroll, { passive: true })
    el._depth = { onScroll }
  },
  unmounted(el) {
    const h = el._depth
    if (h) {
      window.removeEventListener('scroll', h.onScroll)
      window.removeEventListener('resize', h.onScroll)
    }
  },
}
