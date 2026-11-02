// pageIntroFx.js
// 使用原生 JavaScript（document.querySelector）完成的「关于我」页调整，不依赖框架 API。
//
// 调整：将 `body > aside` 从 DOM 中彻底移除（兼容 SPA 路由切换后元素才出现的情况）。
//      说明：本脚本在 app.mount 之后调用一次。

export function initPageIntroFx() {
  // 立即移除一次（若存在）
  const aside = document.querySelector('body > aside')
  if (aside) aside.remove()

  // 监听后续可能出现的 body > aside（SPA 路由切换 / 异步渲染），出现即移除
  if ('MutationObserver' in window) {
    const obs = new MutationObserver(() => {
      const el = document.querySelector('body > aside')
      if (el) {
        el.remove()
        obs.disconnect()
      }
    })
    obs.observe(document.body, { childList: true, subtree: true })
  }
}
