/**
 * person_show · 设计令牌（JS 镜像）
 * 与 src/styles/theme.css 一一对应，供动画/Canvas/图表等需取色值的场景使用。
 * 规范文档：docs/配色标准.md
 */

// 品牌双色（不可改）
export const brand = {
  primary: '#fefcff', // 主色：近白
  secondary: '#b6d4f6', // 辅色：淡蓝
};

// 双主题功能令牌（与 CSS 变量同名语义）
export const tokens = {
  light: {
    bgBase: '#fefcff',
    bgSurface: '#b6d4f6',
    bgElevated: '#ffffff',
    bgSubtle: '#eaf2fc',
    textBase: '#16233b',
    textMuted: '#4a5b73',
    textOnAccent: '#0c1626',
    accent: '#b6d4f6',
    accentHover: '#a3c8f1',
    link: '#25518a',
    focus: '#6fa8e8',
    border: '#cfe0f5',
  },
  dark: {
    bgBase: '#0e1726',
    bgSurface: '#152033',
    bgElevated: '#1d2b42',
    bgSubtle: '#16263f',
    textBase: '#fefcff',
    textMuted: '#b9c6d8',
    textOnAccent: '#0c1626',
    accent: '#b6d4f6',
    accentHover: '#cbe2fb',
    link: '#9cc6f2',
    focus: '#8fc0f5',
    border: '#2a3c57',
  },
};

// 便捷：按当前主题取令牌
export function getTokens(theme = 'light') {
  return tokens[theme] || tokens.light;
}
