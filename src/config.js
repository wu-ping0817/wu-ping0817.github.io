// 站点级配置（纯前端，无后端）
export const siteConfig = {
  // GitHub Pages 部署信息
  github: {
    user: 'wu-ping0817',
    repo: 'wu-ping0817.github.io',
  },
  // 访问统计（纯前端，Umami）
  // 默认关闭；在 Umami 后台创建站点后，把 enabled 改为 true 并填入 src 与 id 即可。
  analytics: {
    umami: {
      enabled: false,
      src: 'https://umami.example.com/script.js',
      id: 'YOUR_UMAMI_ID',
    },
  },
}
