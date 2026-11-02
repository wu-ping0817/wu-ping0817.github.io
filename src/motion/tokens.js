// 动效令牌（与设计文档 §5.2 统一动效语言一致）
// 组件/动画统一引用，避免各处置手写不一致。
export const motion = {
  duration: {
    fast: 160, // 微交互 hover/焦点
    base: 280, // 路由过渡 / 列表 stagger
    slow: 420, // 滚动渐显
  },
  easing: {
    standard: 'cubic-bezier(0.22, 1, 0.36, 1)', // 近似 easeOutExpo
    emphasis: 'cubic-bezier(0.34, 1.56, 0.64, 1)', // 轻微回弹
  },
}

// 供 GSAP / JS 动画取色使用（与 src/theme/tokens.js 同义）
export { brand, tokens } from '@/theme/tokens.js'
