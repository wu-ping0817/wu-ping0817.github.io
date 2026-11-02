// pageTransition.js
// 路由切换时的「逐元素错峰过渡」：
//   - 进入新页面：主要元素（文本 / 图片 / 容器）依次从「左侧或右侧」滑入
//     （奇偶交替方向），并配合明显位移 + 轻微缩放 + 淡入，效果醒目流畅。
//   - 离开当前页面：主要元素依次淡出，并朝与入场相反方向轻移离场。
// 使用 Web Animations API（仅 opacity / transform，合成层友好，性能良好，不阻塞交互）。
// 首屏（首次加载）会等待加载遮罩退场（html.app-loaded）后再播放，避免被遮挡。
// 尊重 prefers-reduced-motion：直接显示，不做任何动画。
//
// 与既有动效的关系：
//   - 替换原先分散的整页入场（v-page3d）、Home 的 homeIn、卡片的 v-reveal，
//     统一由本模块在「路由切换」这一时机协调，避免重复动效与闪烁。
//   - 自包含动画组件（.hb-root，如 Hobbies）作为原子块整体参与，不再向内钻取，
//     其内部的入场仍由组件自身负责。

const ENTER = {
  dur: 760, // 放慢：单元素入场时长
  step: 70, // 放慢：相邻元素错峰步长
  max: 640, // 错峰总上限，避免末位元素等待过久
  ease: 'cubic-bezier(0.16, 1, 0.3, 1)', // 缓出（类 easeOutExpo）：起步利落、收尾极柔，舒缓自然
  dist: 72, // 横向滑入距离（明显、引人注目）
  y: 10, // 极小的纵向托举，配合横向更生动
  scaleFrom: 0.92, // 入场轻微放大，增强视觉张力
}
const LEAVE = {
  dur: 480, // 放慢：单元素离场时长
  step: 38, // 错峰步长
  max: 420, // 错峰总上限
  ease: 'cubic-bezier(0.4, 0, 0.2, 1)', // 标准缓动：离场平稳不突兀
  dist: 54, // 离场横移距离
  y: -12, // 离场轻微上移
  scaleTo: 0.96, // 离场轻微收缩
}

function reduceMotion() {
  return (
    typeof window !== 'undefined' &&
    window.matchMedia &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  )
}

// 跳过自身带「循环装饰动画」的元素（渐变流光、漂浮装饰、呼吸点等），
// 避免与既有无限动画互相打架。
function isSkippable(el) {
  if (!el || el.nodeType !== 1) return true
  const anim = window.getComputedStyle(el).animationName
  if (anim && anim !== 'none') return true
  return false
}

// 收集需要参与过渡的「主要元素」：
//   - 取屏幕根（.screen）的直接子元素为一级块；
//   - 若块内有内容子元素，则动画其子元素（不动画容器本身，避免双重位移）；
//   - 若块为叶子（无子元素），则直接动画该块；
//   - 自包含动画组件（.hb-root）作为原子块整体参与，不再向内钻取。
function collectTargets(root) {
  const out = []
  if (!root) return out
  for (const a of Array.from(root.children)) {
    if (isSkippable(a)) continue
    // 跳过「自带动效的 3D 舞台」：其内部的 CSS-3D 场景不能被通用过渡的
    // opacity/transform 触碰，否则会被压平或残留 opacity:0 导致整块不可见。
    if (a.classList && a.classList.contains('fx-static')) continue
    if (a.classList && a.classList.contains('hb-root')) {
      out.push(a)
      continue
    }
    const kids = Array.from(a.children).filter((k) => !isSkippable(k))
    if (kids.length === 0) {
      out.push(a)
    } else {
      for (const k of kids) out.push(k)
    }
  }
  return out
}

// 入场「起始」变换：按奇偶交替从左侧 / 右侧滑入
function enterFromTransform(i) {
  const side = i % 2 === 0 ? -1 : 1 // 偶数→左，奇数→右
  return `translate3d(${side * ENTER.dist}px, ${ENTER.y}px, 0) scale(${ENTER.scaleFrom})`
}

// 离场「结束」变换：朝与入场相反方向滑出（偶数来自左→向右离场，奇数来自右→向左离场）
function leaveToTransform(i) {
  const side = i % 2 === 0 ? 1 : -1
  return `translate3d(${side * LEAVE.dist}px, ${LEAVE.y}px, 0) scale(${LEAVE.scaleTo})`
}

function clearInline(t) {
  t.style.opacity = ''
  t.style.transform = ''
  t.style.willChange = ''
}

function animateIn(targets, done) {
  const anims = targets.map((t, i) => {
    const delay = Math.min(i * ENTER.step, ENTER.max)
    const a = t.animate(
      [
        { opacity: 0, transform: enterFromTransform(i) },
        { opacity: 1, transform: 'translate3d(0, 0, 0) scale(1)' },
      ],
      { duration: ENTER.dur, easing: ENTER.ease, delay, fill: 'both' }
    )
    a.finished
      .then(() => {
        a.cancel() // 释放合成层，回退到 CSS 自然状态（可见、无位移）
        clearInline(t)
      })
      .catch(() => {
        // 动画被中断（组件卸载 / HMR / done 多次调用等）时也必须清理内联样式，
        // 否则会残留 opacity:0 / transform，导致元素永久不可见。
        try {
          a.cancel()
        } catch (e) {}
        clearInline(t)
      })
    return a
  })
  if (!anims.length) {
    done()
    return
  }
  Promise.all(anims.map((a) => a.finished))
    .then(() => done())
    .catch(() => done())
}

function animateOut(targets, done) {
  const anims = targets.map((t, i) => {
    const delay = Math.min(i * LEAVE.step, LEAVE.max)
    // 离场保持 fill:both，动画结束后维持隐藏态直到元素被卸载
    return t.animate(
      [
        { opacity: 1, transform: 'translate3d(0, 0, 0) scale(1)' },
        { opacity: 0, transform: leaveToTransform(i) },
      ],
      { duration: LEAVE.dur, easing: LEAVE.ease, delay, fill: 'both' }
    )
  })
  if (!anims.length) {
    done()
    return
  }
  Promise.all(anims.map((a) => a.finished))
    .then(() => done())
    .catch(() => done())
}

// 进入钩子（同时用于首次加载的 appear 与后续路由切换）：
// Vue 的 <transition> 在 :css="false" 下依赖 done() 收尾。
export function runEnter(el, done) {
  const targets = collectTargets(el)
  if (!targets.length || reduceMotion()) {
    done()
    return
  }

  // 预置隐藏 + 起始位姿：防止「等待加载遮罩退场」或「动画开始」前出现内容闪烁
  targets.forEach((t, i) => {
    t.style.opacity = '0'
    t.style.transform = enterFromTransform(i)
    t.style.willChange = 'opacity, transform'
  })

  const start = () => animateIn(targets, done)

  // 非首屏（已加载过）：直接播放
  if (document.documentElement.classList.contains('app-loaded')) {
    start()
    return
  }

  // 首屏：等待加载遮罩退场（html.app-loaded）后再播放，避免被遮挡
  let started = false
  const begin = () => {
    if (started) return
    started = true
    if (observer) observer.disconnect()
    clearTimeout(safety)
    start()
  }
  const observer = new MutationObserver(() => {
    if (document.documentElement.classList.contains('app-loaded')) begin()
  })
  observer.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['class'],
  })
  const safety = setTimeout(begin, 4000) // 兜底：异常时强制播放，绝不永久隐藏
}

// 离场钩子：当前页面元素依次缓出
export function runLeave(el, done) {
  const targets = collectTargets(el)
  if (!targets.length || reduceMotion()) {
    done()
    return
  }
  animateOut(targets, done)
}
