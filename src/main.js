import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { reveal } from './directives/reveal'
import { scrollFx } from './directives/scrollFx'
import { tilt } from './directives/tilt'
import { depth } from './directives/depth'
import { revealGroup } from './directives/revealGroup'
import { useThemeStore } from './stores/theme'
import { initAnalytics } from './analytics/umami'
import { initPageIntroFx } from './scripts/pageIntroFx'

import './styles/theme.css' // 双主题配色令牌（正式标准）
import './styles/base.css'  // 基础重置 / 排版 / 动效类
import './styles/anim-3d.css' // 三维动效层（v-tilt / v-depth / v-page3d 配套）
import './styles/click-feedback.css' // 全局点击反馈（:active 按压态 + 涟漪宿主基底）

const app = createApp(App)
const pinia = createPinia()
app.use(pinia)
app.use(router)
app.directive('reveal', reveal) // 滚动渐显指令：v-reveal（一次性）
app.directive('scroll-fx', scrollFx) // 滚动联动持续动效：v-scroll-fx
app.directive('tilt', tilt) // 指针 3D 悬停倾斜：v-tilt
app.directive('depth', depth) // 滚动联动 3D 纵深视差：v-depth
app.directive('reveal-group', revealGroup) // 板块内容「依次逐个」滚动渐显（可重复触发）：v-reveal-group

// 初始化主题：读取 localStorage，无则跟随系统偏好
useThemeStore(pinia).init()

app.mount('#app')

// 原生 JS 页面调整：移除 body>aside + 关于我页面 intro 渐进式滑入入场
initPageIntroFx()

// 纯前端访问统计（默认关闭，见 src/config.js）
initAnalytics()
