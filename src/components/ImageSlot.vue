<script setup>
import { ref, computed } from 'vue'

/**
 * ImageSlot：图片占位容器（主题化、可降级为代码生成的视觉块）。
 * - 图片就位前显示「代码生成的视觉块」（主题色渐变 + 几何感点缀 + 标题），
 *   而非空白或破图——这样未提供静态图时页面依然美观、视觉统一，
 *   从而减少必须提供的图片数量。
 * - 图片放入 public/img/ 后自动显示；加载失败（文件缺失）时回退到占位。
 * - src 使用相对 public 的路径，如 'img/avatar.webp'；内部自动拼接 BASE_URL，
 *   兼容 GitHub Pages 根路径与后续可能的子路径部署。
 *
 * variant:
 *   'cover'（默认）—— 封面类（作品/图片）：占位显示标题文字。
 *   'photo'        —— 头像类：占位显示姓名首字母。
 */
const props = defineProps({
  src: { type: String, default: '' }, // 相对 public 的路径，如 'img/avatar.webp'
  alt: { type: String, default: '' },
  label: { type: String, default: '图片' }, // 占位回退文字
  title: { type: String, default: '' }, // 占位时展示的标题（优先于 label）
  ratio: { type: String, default: '' }, // CSS aspect-ratio，如 '1 / 1'、'16 / 9'
  round: { type: Boolean, default: false }, // 圆形（头像）
  variant: { type: String, default: 'cover' }, // 'cover' | 'photo'
})

// 默认显示占位；图片真正加载成功（load）后才覆盖占位。
// 缺失文件时浏览器触发 error，占位持续显示，不会出现 broken image 闪烁。
const ready = ref(false)
const url = computed(() =>
  props.src ? import.meta.env.BASE_URL + props.src.replace(/^\/+/, '') : ''
)
const placeholderText = computed(() => props.title || props.label)
const initial = computed(() =>
  (props.title || props.label || '').trim().charAt(0).toUpperCase()
)
</script>

<template>
  <div
    class="img-slot"
    :class="[round || variant === 'photo' ? 'img-slot--round' : '', `img-slot--${variant}`]"
    :style="ratio ? { aspectRatio: ratio } : null"
  >
    <!-- 代码生成的占位：无图时仍美观，减少必须提供的静态图片 -->
    <div v-show="!ready" class="img-slot__ph">
      <span class="img-slot__shimmer" aria-hidden="true"></span>
      <span v-if="variant === 'photo'" class="img-slot__initial">{{ initial }}</span>
      <span v-else class="img-slot__title">{{ placeholderText }}</span>
    </div>
    <img
      v-if="url"
      class="img-slot__img"
      :class="{ 'is-ready': ready }"
      :src="url"
      :alt="alt"
      loading="lazy"
      decoding="async"
      @load="ready = true"
      @error="ready = false"
    />
  </div>
</template>

<style scoped>
.img-slot {
  position: relative;
  width: 100%;
  max-width: 100%;
  overflow: hidden;
  border-radius: 12px;
  background:
    radial-gradient(
      circle at 22% 18%,
      color-mix(in srgb, var(--color-accent) 38%, transparent),
      transparent 62%
    ),
    linear-gradient(135deg, var(--color-bg-elevated), var(--color-bg-subtle));
  display: grid;
  place-items: center;
  color: var(--color-text-on-surface);
}
.img-slot--round {
  border-radius: 50%;
}
.img-slot__ph {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 0.6rem;
  text-align: center;
}
/* 几何点缀：旋转渐变环，强化“代码生成视觉”而非空白 */
.img-slot__ph::before {
  content: '';
  position: absolute;
  width: 56%;
  aspect-ratio: 1;
  border-radius: 50%;
  border: 1px dashed color-mix(in srgb, var(--color-accent) 45%, transparent);
  opacity: 0.5;
}
.img-slot--photo .img-slot__ph::before {
  display: none;
}
.img-slot__title {
  position: relative;
  font-size: 0.82rem;
  opacity: 0.82;
  letter-spacing: 0.05em;
  line-height: 1.4;
}
.img-slot__initial {
  position: relative;
  font-size: 1.7rem;
  font-weight: 700;
  color: var(--color-accent-strong, var(--color-accent));
}
/* 占位加载态微光：缓慢扫过，传达"生成中"，纯装饰 */
.img-slot__shimmer {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    100deg,
    transparent 30%,
    color-mix(in srgb, var(--color-accent) 22%, transparent) 50%,
    transparent 70%
  );
  background-size: 220% 100%;
  animation: slotShimmer 1.8s ease-in-out infinite;
}
@keyframes slotShimmer {
  from {
    background-position: 180% 0;
  }
  to {
    background-position: -80% 0;
  }
}
.img-slot__img {
  width: 100%;
  height: 100%;
  /* 非圆形（普通图片）：完整显示整图、保持原始宽高比、不裁切、不溢出 */
  object-fit: contain;
  display: block;
  /* 加载完成淡入 + 轻微缩放，作为"内容加载过渡" */
  opacity: 0;
  transform: scale(1.04);
  transition: opacity 0.55s ease, transform 0.6s var(--ease-standard);
}
/* 圆形头像：填满圆形区域（标准头像裁切，不失真） */
.img-slot--round .img-slot__img {
  object-fit: cover;
}
.img-slot__img.is-ready {
  opacity: 1;
  transform: scale(1);
}

@media (prefers-reduced-motion: reduce) {
  .img-slot__shimmer {
    animation: none;
  }
  .img-slot__img {
    transition: opacity 0.3s ease;
    transform: none;
  }
}
</style>
