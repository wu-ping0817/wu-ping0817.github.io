<script setup>
import { ref, reactive, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import DefaultLayout from '@/layouts/DefaultLayout.vue'
import LoadingScreen from '@/components/LoadingScreen.vue'
import ClickRipple from '@/components/ClickRipple.vue'
import RouteFX from '@/components/RouteFX.vue'
import { runEnter, runLeave } from '@/scripts/pageTransition'

const router = useRouter()

// 全屏加载动画仅在应用首次挂载时展示一次（路由切换不再出现）
// ?noloader：调试/自动化截图（无头浏览器）用，直接跳过加载屏
const loading = ref(!new URLSearchParams(window.location.search).has('noloader'))

// 路由切换过渡装饰层状态（图标 / 进度环 / 色彩区块 / 图形）
const fx = reactive({ visible: false, target: null })
let fxTimer = null

// 导航开始前捕获目标路由名，供装饰层显示「即将前往」的页面图标
// 用实例标记避免 HMR 重复注册守卫
if (!router.__fxGuard) {
  router.beforeEach((to) => {
    fx.target = to.name || null
    return true
  })
  router.__fxGuard = true
}

// 离开旧页：显示过渡装饰层（色彩区块 / 图形 / 进度环 + 图标）
function onBeforeLeave() {
  fx.visible = true
  // 过渡期间关闭导航玻璃模糊，避免面板在其后移动时「模糊套模糊」逐帧重算导致卡顿
  document.body.classList.add('is-transitioning')
  clearTimeout(fxTimer)
  fxTimer = setTimeout(() => {
    fx.visible = false
    document.body.classList.remove('is-transitioning') // 兜底：异常时强制收起
  }, 2600)
}
// 进入新页完成：收起装饰层
function onAfterEnter() {
  clearTimeout(fxTimer)
  fx.visible = false
  document.body.classList.remove('is-transitioning')
}

// 加载完成后在 <html> 上标记 app-loaded，触发首屏(#top)入场动画，
// 确保动画在加载遮罩退场之后才播放；并设置兜底，避免异常情况导致首屏不可见。
function markLoaded() {
  document.documentElement.classList.add('app-loaded')
}
watch(loading, (v) => {
  if (!v) markLoaded()
})
onMounted(() => {
  // 兜底：即使加载流程异常，也保证首屏内容最终可见
  setTimeout(markLoaded, 7000)
})
</script>

<template>
  <DefaultLayout>
    <router-view v-slot="{ Component }">
      <transition
        :css="false"
        appear
        @enter="runEnter"
        @leave="runLeave"
        @before-leave="onBeforeLeave"
        @after-enter="onAfterEnter"
        mode="out-in"
      >
        <component :is="Component" />
      </transition>
    </router-view>
  </DefaultLayout>

  <LoadingScreen v-if="loading" @finished="loading = false" />

  <!-- 全站点击波纹反馈：常驻、跨路由共享、pointer-events:none 不拦截交互 -->
  <ClickRipple />

  <!-- 路由切换过渡装饰层：色彩区块 / 图形 / 进度环 + 图标 -->
  <RouteFX :visible="fx.visible" :target="fx.target" />
</template>
