# 温暖 · 个人作品集展示（person_show）

纯前端个人作品集展示站点：以作品集为核心、设计向关于我为辅，并含联系页与站内搜索。技术栈 **Vue 3 + Vite + Vue Router + Pinia**，双主题（暗/亮可切换），内容以仓库内 JSON 维护（Git 即 CMS），构建产物为纯静态文件，可直接托管到 GitHub Pages。

---

## 1. 目录结构及用途

```
person_show/
├─ index.html              # 应用入口 HTML（挂载 #app，预置 data-theme）
├─ vite.config.js          # Vite 配置：@ 别名、base 路径（GitHub Pages 友好）
├─ package.json            # 依赖与脚本（dev / build / preview）
├─ .gitignore
├─ README.md
├─ data/                   # 内容数据层（构建期静态化）
│  ├─ profile.json         # 个人简介 / 技能 / 设计内容
│  └─ portfolio.json       # 作品集（类别 / 作品 / 源码 / 演示）
├─ public/                 # 纯静态资源（构建时原样拷贝）
└─ src/
   ├─ main.js              # 应用启动：装配 Pinia / Router / 主题 / 指令 / 统计
   ├─ App.vue              # 根组件：布局 + 路由过渡
   ├─ config.js            # 站点级配置（GitHub Pages / 访问统计开关）
   ├─ router/
   │  └─ index.js          # 客户端路由（首页/作品集/关于我/联系）
   ├─ stores/
   │  └─ theme.js          # Pinia 主题状态：初始化 / 切换 / 持久化
   ├─ layouts/
   │  └─ DefaultLayout.vue # 全局布局：导航 / 内容槽 / 页脚
   ├─ components/
   │  ├─ ThemeToggle.vue   # 主题切换按钮（图标 + 文本）
   │  └─ ImageSlot.vue     # 图片占位组件（图缺失时显示占位，就位自动替换）
   ├─ directives/
   │  └─ reveal.js         # v-reveal 滚动渐显指令（尊重 reduced-motion）
   ├─ composables/
   │  ├─ useParallax.js    # 指针视差（Hero 背景）
   │  └─ useContent.js     # 内容数据访问入口（对接 data/）
   ├─ analytics/
   │  └─ umami.js          # 纯前端访问统计（默认关闭，见 config.js）
   ├─ motion/
   │  └─ tokens.js         # 动效令牌（时长 / 缓动）+ 色板导出
   ├─ theme/
   │  └─ tokens.js         # 双主题色板 JS 镜像（供动画/Canvas 取色）
   ├─ styles/
   │  ├─ theme.css         # ★ 双主题配色令牌（正式标准，见 docs/配色标准.md）
   │  └─ base.css          # 基础重置 / 排版 / 路由过渡 / 渐显类
   └─ pages/
      ├─ Home.vue          # M1 首页 Hero（视差 + 渐显 + 精选作品）
      ├─ Portfolio.vue     # M3 作品集（按类别 + 代码成品 + 站内搜索）
      ├─ About.vue         # M4 关于我（设计理念 / 审美 / 能力 / 设计作品）
      └─ Contact.vue       # 联系页（纯展示：GitHub / 邮箱 / 微信）
```

> 模块划分对应设计文档：展示层 M1/M3/M4/Contact、数据层（data/ + useContent）、支撑层 M7（motion/reveal/parallax）、M8（styles/theme.css + stores/theme）。

---

## 2. 启动前置条件与操作步骤

### 2.1 环境要求
- **Node.js ≥ 18**（推荐 20 LTS / 22）。可在终端执行 `node -v` 确认。
- **npm**（随 Node 自带）。`npm -v` 确认。
- 可正常访问 npm 源（首次需安装依赖）。

### 2.2 安装依赖
```bash
# 进入项目目录
cd person_show

# 安装依赖（生成 node_modules）
npm install
```

### 2.3 本地启动（开发模式）
```bash
npm run dev
```
启动后终端会输出本地地址（默认 `http://localhost:5173`），在浏览器打开即可。

### 2.4 构建与预览（生产）
```bash
npm run build      # 输出静态文件到 dist/
npm run preview    # 本地预览构建产物（默认 http://localhost:4173）
```

### 2.5 部署到 GitHub Pages（个人主页）
1. `npm run build` 生成 `dist/`。
2. 通过 GitHub Actions（checkout → setup-node → build → deploy to Pages）或推送 `gh-pages` 分支发布。
3. 本仓库已按仓库名 `wu-ping0817` 设置 `base: '/wu-ping0817/'`（项目页）。若改为「用户页」（仓库名为 `wu-ping0817.github.io`），把 `vite.config.js` 的 `base` 改回 `'/'`。
4. 访问统计默认关闭；在 Umami 后台建站后，将 `src/config.js` 的 `analytics.umami.enabled` 改为 `true` 并填入 `src` 与 `id` 即可。

---

## 3. 验证项目成功启动

**开发模式验证**
1. 执行 `npm run dev`，终端出现 `VITE ready` 与本地地址，且无报错。
2. 浏览器打开该地址，能看到首页 Hero「把内容，展示成一种体验」与导航栏。
3. 点击右上角「暗色 / 亮色」按钮，整站颜色平滑切换并在刷新后保持（localStorage 持久化）。
4. 依次访问 `/portfolio`、`/about`、`/contact`，页面切换有淡入过渡，滚动时卡片渐显。
5. 在 `/portfolio` 顶部搜索框输入关键词（如 `vue`、`可视化`），作品列表实时过滤。

**构建验证**
1. 执行 `npm run build`，终端输出 `✓ built in ...` 且无错误。
2. 项目根目录生成 `dist/`（含 `index.html` 与静态资源）。
3. 执行 `npm run preview` 可正常浏览构建产物。

> 若启动失败，优先检查 Node 版本（≥18）与 `npm install` 是否成功；常见为端口占用，可改 `vite.config.js` 的 `server.port`。

---

## 4. 设计约定（已落地）
- 配色严格使用 `src/styles/theme.css` 的令牌变量，**禁止硬编码色值**；规范见 `docs/配色标准.md`。
- 新增页面：在 `src/pages/` 建组件 → `src/router/index.js` 注册路由 → 在 `DefaultLayout` 的 `nav` 增加入口即可。
- 内容更新：编辑 `data/*.json`（后续可扩展为 Markdown + SSG，展示层无需改动）。
