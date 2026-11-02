/**
 * v-scroll-fx 指令：滚动联动的持续动效。
 *
 * 与「进入视口一次性播放」不同，本指令让元素的外观（透明度 / 位移）始终
 * 跟随其在视口中的滚动位置连续变化：
 *   - 进入视口过程中透明度由 0 → 1（渐显）
 *   - 无论是否进入，translateY 始终与滚动位置绑定（视差），形成持续联动
 * 因此动画不会「加载/触发一次后结束」，而是随页面滚动持续响应。
 *
 * 用法：
 *   <section v-scroll-fx>                          默认：淡入 + 轻微视差
 *   <div v-scroll-fx="{ y: 60, parallax: 0.1 }">   自定义位移幅度与视差系数
 *
 * 尊重 prefers-reduced-motion：直接静态显示，关闭一切联动。
 */
export const scrollFx = {
  mounted(el, binding) {
    const opts = binding.value || {}
    const parallax = opts.parallax ?? 0.08 // 视差系数：位移 = 中心偏移 × 系数
    const reduce = window.matchMedia?.(
      '(prefers-reduced-motion: reduce)'
    ).matches

    if (reduce) {
      el.style.opacity = '1'
      el.style.transform = 'none'
      el.classList.add('scroll-fx-ready')
      return
    }

    let ticking = false
    const update = () => {
      ticking = false
      const rect = el.getBoundingClientRect()
      const vh = window.innerHeight || document.documentElement.clientHeight

      // 完全在视口下方：保持隐藏初始态
      if (rect.top > vh) {
        el.style.opacity = '0'
        el.style.transform = 'translate3d(0, 0, 0)'
        return
      }
      // 完全在视口上方（已滚过）：不再隐藏，保留视差位移
      if (rect.bottom < 0) {
        el.style.opacity = '1'
      } else {
        // 进入行程：0 = 刚从底部进入，1 = 完全穿过
        const travel = vh + rect.height
        let p = (vh - rect.top) / travel
        p = Math.min(1, Math.max(0, p))
        // 前 35% 行程内完成渐显，之后保持可见
        const op = Math.min(1, p / 0.35)
        el.style.opacity = op.toFixed(3)
      }

      // 视差：以元素中心相对视口中心的偏移为基准，持续随滚动变化
      const centerDelta = rect.top + rect.height / 2 - vh / 2
      const ty = (-centerDelta * parallax).toFixed(1)
      el.style.transform = `translate3d(0, ${ty}px, 0)`
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
    el._scrollFx = { onScroll }
    el.classList.add('scroll-fx-ready')
  },
  unmounted(el) {
    const h = el._scrollFx
    if (h) {
      window.removeEventListener('scroll', h.onScroll)
      window.removeEventListener('resize', h.onScroll)
    }
  },
}
