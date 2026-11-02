/**
 * v-reveal-group 指令：当其挂载的「容器 / 板块」进入视口时，
 * 内部带 .reveal-item 的子元素按 DOM 顺序「依次逐个」淡入 + 上滑进入视口；
 * 当板块离开视口时复位（隐藏），再次进入（包含向上回滚回来）时重新触发。
 *
 * 与 v-reveal（单元素、一次性）的区别：
 *   - 本指令负责「一个板块内多个内容元素的有序级联渐显」；
 *   - 可被反复触发（向上回滚 / 向下再滚入都会重新播放），非一次性。
 *
 * 用法：
 *   <section v-reveal-group>                 默认：.reveal-item 子元素依次渐显（间隔 120ms）
 *   <section v-reveal-group="{ step: 160 }"> 自定义每两个元素之间的错峰间隔（ms）
 * 子元素需带 .reveal-item 类；可加 data-reveal-delay="200" 追加额外延迟。
 *
 * 性能：仅用 IntersectionObserver（无 scroll 监听、零主线程轮询）；过渡只动
 *   opacity / transform（合成层友好）；will-change 仅在隐藏 / 动画态启用，
 *   可见后释放——滚动流畅度不受影响。尊重 prefers-reduced-motion。
 */
export const revealGroup = {
  mounted(el, binding) {
    const opts = binding.value || {}
    const step = Number(opts.step) || 120
    const items = Array.from(el.querySelectorAll('.reveal-item'))
    if (!items.length) return

    const reduce = window.matchMedia?.(
      '(prefers-reduced-motion: reduce)'
    ).matches
    if (reduce) {
      items.forEach((it) => it.classList.add('is-visible'))
      return
    }

    let timers = []
    let shown = false

    // 逐元素判定：该子项是否已真正滚出视口（整体在视口上沿以上或下沿以下）
    const isOutOfView = (it) => {
      const r = it.getBoundingClientRect()
      const vh = window.innerHeight || document.documentElement.clientHeight
      return r.bottom <= 0 || r.top >= vh
    }

    const show = () => {
      if (shown) return
      shown = true
      items.forEach((it, i) => {
        const extra = Number(it.dataset.revealDelay) || 0
        timers.push(
          setTimeout(() => it.classList.add('is-visible'), extra + i * step)
        )
      })
    }
    // 复位：仅抹除「已真正滚出视口」的子项；仍可见的子项（含点击展开后改变了
    // 布局高度的卡片）保持 is-visible。避免观察整段 <section> 时，因点击展开导致
    // 布局/几何变化、section 相交比瞬时低于阈值而触发 hide()，把仍在眼前的内容
    // 一并全量抹除（连坐式消失）。force=true 用于卸载时强制清空。
    const hide = (force) => {
      shown = false
      timers.forEach(clearTimeout)
      timers = []
      items.forEach((it) => {
        if (force || isOutOfView(it)) it.classList.remove('is-visible')
      })
    }

    let io = null
    if ('IntersectionObserver' in window) {
      io = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) show()
            else hide() // 离开视口即复位 → 再次进入可重新触发（含向上回滚）
          })
        },
        // 顶部略微提前、底部 -10% 让「刚露头」就开始，离开时稍滞后于完全离开
        { threshold: 0.12, rootMargin: '0px 0px -10% 0px' }
      )
      io.observe(el)
    } else {
      show() // 无 IO 支持时直接展示
    }

    // 兜底：极端情况下 IO 未触发（如容器异常），1.6s 后强制显示，绝不永久隐藏
    const safety = setTimeout(show, 1600)

    el._revealGroup = { io, safety, hide }
  },
  unmounted(el) {
    const h = el._revealGroup
    if (h) {
      h.io?.disconnect()
      clearTimeout(h.safety)
      h.hide?.(true)
    }
  },
}
