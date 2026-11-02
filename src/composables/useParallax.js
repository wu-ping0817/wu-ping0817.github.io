import { onMounted, onBeforeUnmount, ref } from 'vue'

/**
 * useParallax：根据指针/滚动位置返回位移比例，用于 Hero 背景视差。
 * 返回 { x, y }（范围约 -1 ~ 1），组件内绑定到 transform 即可。
 * 尊重 prefers-reduced-motion：降级时不监听。
 */
export function useParallax(strength = 0.04) {
  const x = ref(0)
  const y = ref(0)
  let cleanup = null

  onMounted(() => {
    const reduce = window.matchMedia?.(
      '(prefers-reduced-motion: reduce)'
    ).matches
    if (reduce) return

    const onMove = (e) => {
      const cx = window.innerWidth / 2
      const cy = window.innerHeight / 2
      x.value = (e.clientX - cx) / cx * strength
      y.value = (e.clientY - cy) / cy * strength
    }
    window.addEventListener('pointermove', onMove, { passive: true })
    cleanup = () => window.removeEventListener('pointermove', onMove)
  })

  onBeforeUnmount(() => cleanup?.())
  return { x, y }
}
