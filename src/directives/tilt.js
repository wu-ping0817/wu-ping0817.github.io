/**
 * v-tilt：指针驱动的 3D 悬停倾斜（复用性强，任意元素可加）。
 *
 * 用法：
 *   <div v-tilt>
 *   <div v-tilt="{ max: 10, scale: 1.03, perspective: 800 }">
 *
 * 行为：指针移到元素 → 按光标相对中心的位置计算 rotateX / rotateY（最大 max 度），
 *       离开 → 平滑复位为初始态。所有位移仅用 transform（GPU 合成），
 *       配合 box-shadow 过渡保持与既有 hover 阴影一致。
 * 兼容性：尊重 prefers-reduced-motion（降级为无动画）；触屏无 hover 时自然不触发。
 */
export const tilt = {
  mounted(el, binding) {
    const reduce = window.matchMedia?.(
      '(prefers-reduced-motion: reduce)'
    ).matches
    if (reduce) return

    const o = binding.value || {}
    const max = o.max ?? 8 // 最大倾斜角度（度）
    const scale = o.scale ?? 1.02
    const perspective = o.perspective ?? 900

    el.style.transformStyle = 'preserve-3d'
    el.style.willChange = 'transform'
    // 保留 box-shadow 过渡，使既有 :hover 阴影依旧平滑
    el.style.transition =
      'transform 0.3s var(--ease-standard), box-shadow 0.3s var(--ease-standard)'

    let raf = 0
    const onMove = (e) => {
      const r = el.getBoundingClientRect()
      const px = (e.clientX - r.left) / r.width - 0.5
      const py = (e.clientY - r.top) / r.height - 0.5
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(() => {
        const rx = (-py * max).toFixed(2)
        const ry = (px * max).toFixed(2)
        el.style.transform = `perspective(${perspective}px) rotateX(${rx}deg) rotateY(${ry}deg) scale(${scale})`
      })
    }
    const onLeave = () => {
      cancelAnimationFrame(raf)
      el.style.transform = ''
    }

    el.addEventListener('pointermove', onMove)
    el.addEventListener('pointerleave', onLeave)
    el._tilt = { onMove, onLeave }
  },
  unmounted(el) {
    const h = el._tilt
    if (h) {
      el.removeEventListener('pointermove', h.onMove)
      el.removeEventListener('pointerleave', h.onLeave)
    }
  },
}
