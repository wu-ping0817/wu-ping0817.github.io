/**
 * v-page3d：页面 / 区块的 3D 入场动画（从透视中展开）。
 *
 * 用法：
 *   <section v-page3d>                      页面首屏 / 主区块
 *   <section v-page3d="{ delay: 120 }">     带错峰延迟（ms）
 *
 * 行为：挂载时先隐藏（透视 rotateX + 下移 + 后移 + 透明），随后平滑展开归位。
 *   - 首次加载：等待 html.app-loaded（加载遮罩退场后）再播放，避免被遮挡；
 *   - 路由切换：app-loaded 已存在，挂载即播放。
 * 可靠性：7s 兜底强制播放 + MutationObserver 监听 app-loaded，绝不永久隐藏。
 * 可访问性：prefers-reduced-motion 下直接显示，无动画。
 */
export const page3d = {
  mounted(el, binding) {
    const reduce = window.matchMedia?.(
      '(prefers-reduced-motion: reduce)'
    ).matches
    if (reduce) return // 降级：保持默认（opacity:1），不做动画

    const delay = Number(binding.value?.delay) || 0

    el.style.willChange = 'transform, opacity'
    el.style.opacity = '0'
    el.style.transform =
      'perspective(1400px) rotateX(9deg) translateY(26px) translateZ(-70px)'
    el.style.transition =
      'opacity .55s var(--ease-standard), transform .7s var(--ease-standard)'

    let timer = null
    const play = () => {
      timer = setTimeout(() => {
        el.style.opacity = '1'
        el.style.transform =
          'perspective(1400px) rotateX(0deg) translateY(0) translateZ(0)'
      }, delay)
    }

    let obs = null
    if (document.documentElement.classList.contains('app-loaded')) {
      play()
    } else {
      obs = new MutationObserver(() => {
        if (document.documentElement.classList.contains('app-loaded')) {
          obs.disconnect()
          obs = null
          play()
        }
      })
      obs.observe(document.documentElement, {
        attributes: true,
        attributeFilter: ['class'],
      })
    }

    // 兜底：无论如何 7s 后强制播放，避免异常时永久隐藏
    const safety = setTimeout(() => {
      if (obs) {
        obs.disconnect()
        obs = null
      }
      play()
    }, 7000)

    el._page3d = { obs, safety, timer }
  },
  unmounted(el) {
    const h = el._page3d
    if (h) {
      h.obs?.disconnect()
      clearTimeout(h.safety)
      clearTimeout(h.timer)
    }
  },
}
