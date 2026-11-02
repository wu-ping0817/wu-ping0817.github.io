<script setup>
import ParticlesBg from '@/components/particles/ParticlesBg.vue'
import SiteNav from '@/components/SiteNav.vue'
</script>

<template>
  <div class="layout">
    <!-- 全站共享的三维粒子背景：固定视口、置于所有前景内容之下、不拦截任何交互。
         放在布局层而非各页面，使背景在「页面切换」时持续运行、不重新初始化（不闪烁）。 -->
    <div class="layout-particles" aria-hidden="true">
      <ParticlesBg />
    </div>

    <main class="content">
      <slot />
    </main>

    <!-- 向导式导航：底部浮层，按固定顺序逐页引导浏览（上一页 / 进度圆点 / 下一页 + 主题切换） -->
    <SiteNav />
  </div>
</template>

<style scoped>
.layout {
  position: relative;
  min-height: 100dvh;
}

/* 全站共享三维粒子背景：固定于视口、位于所有前景内容之下、不拦截任何点击。
   注意：z-index 必须是 0（或正数），绝不能再用 -1（会被 body 底色整层盖住，导致看不到粒子）。 */
.layout-particles {
  position: fixed;
  inset: 0;
  z-index: 0;
  pointer-events: none;
}

.content {
  position: relative;
  z-index: 1;
  /* 不在此设不透明底色；页面底色由 body 提供（theme.css）。
     本层若加不透明背景，会盖住 z-index:0 的粒子层。 */
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
}
</style>
