# 关于我页 · 趣味化文案与交互创意方案

> 目标：在现有「轻俏皮 + 微治愈 + 不端着」人设基础上，把播放按钮及其他同类元素（标题 / 说明 / 提示标签）的文案与交互做得更有创意、更一致、更想让人点。
> 基调参考：易被小事打动、有点笨拙可爱、自我调侃、温暖。受众是「新人」（招新宣传调性）。
> 约束：保留 ▶ 图标与既有幽灵按钮 / 虚线描边视觉；全部交互尊重 `prefers-reduced-motion`。

---

## 一、核心对象：`intro-play-btn`（播放按钮）

保留 ▶ 图标、虚线描边、accent 配色。下面按 4 种语调给替代文案，**建议默认采用「行动号召」里的推荐项**。

### 1) 俏皮（可爱、不正经）
- `▶ 点我，有猫腻`
- `▶ 别愣着，戳一下`
- `▶ 让我醒过来嘛`
- `▶ 你不想看看吗`

### 2) 悬念感（勾起好奇，不剧透）
- `▶ 这里藏了点东西`
- `▶ 先别划走，点这个`
- `▶ 一个不想剧透的按钮`
- `▶ 秘密，点开才知道`

### 3) 行动号召 / CTA（推荐）
- **`▶ 唤醒我的名片`** ← 推荐默认（CTA + 一点悬念，和「身份卡」呼应）
- `▶ 解锁完整版我`
- `▶ 开始播放`
- `▶ 把页面叫醒`

### 4) 治愈 / 文艺（慢节奏）
- `▶ 让画面慢慢醒来`
- `▶ 它想跟你打个招呼`
- `▶ 听，它开始讲了`

**按钮交互增强（统一规范）**
- hover：`▶` 做小幅「摆动 / 旋转」微动（`@keyframes wiggle`），文案可临时切到 `正在唤醒…`；
- 点击瞬间：`:active` 缩放 `0.97`，图标短暂变 `✨` 或 `⏸`，随后回到 `▶`；
- 已播放后：按钮文案可变为 `▶ 再看一遍`（明确可重播）；
- 全部过渡仅 `transform / opacity`，`reduced-motion` 下关闭摆动。

---

## 二、其他同类元素：「趣味化 + 风格统一」

| 元素 | 现有文案 | 趣味方案 A | 趣味方案 B | 视觉 / 交互 |
|---|---|---|---|---|
| 页面标题 `.page-title` | 关于我 | `关于我（一点点）` | `这就是我啦` | 标题下方加一道「手绘感」下划线，hover 时 `scaleX(0→1)` 展开；可加小角标 `·不正经版` |
| 身份副标 `.role` | 只会一点点代码 | 保持（已很好） | `代码？只会一点点 ✦` | 末尾加一个会「呼吸」的小星点 |
| 状态标签 `.mood-label` | 此刻的我 | `脑子里的弹幕` | `我现在：` | 前加一个跳动的「● 直播中」小圆点（呼吸动画） |
| 板块标题 `.section-h` | 有点喜欢的东西 | 保持（已很好） | `藏起来的一点喜欢` | 保持，hover 出现小下划线 |
| 爱好占位 `.hobby--placeholder` | ＋ 更多爱好，待补充 | `＋ 这一格，留给下次相遇` | `＋ 我的隐藏爱好，等你来挖` | 虚线边框 hover 时「流动」虚线 + 轻微上浮 |
| 资料按钮 `.detail-btn` | 详细资料 → | `翻开我的小档案 →` | `更多关于我 →` | 箭头 hover 右移（已有），文案更有人味 |
| 面板标题 `.panel-h` | 联系方式 | `怎么找到我` | `来撩我呀` | 保持面板结构，仅换标题 |
| 面板提示 `.panel-note` | 邮箱与微信待补充… | `邮箱微信还在路上，填了就显示～` | 同左，更口语 | 保持 |

> 说明：`.mood-text`（5 句状态）本身已足够有趣，**不建议改动**，避免破坏一致性。

---

## 三、统一视觉 / 交互规范（让整页「生动一致」）

1. **趣味标签规范**：小号、字距加宽、accent 色；可前置一个「呼吸圆点」`●`（CSS `opacity` 1→0.3 循环）。
2. **标题下划线**：`.page-title` / `.section-h` 加伪元素下划线，默认 `transform: scaleX(0)`，`hover` / `is-visible` 时 `scaleX(1)`，缓动 `cubic-bezier(.22,.61,.36,1)`。
3. **提示标签（占位）动效**：`border: 1px dashed` + `@keyframes dash` 让虚线「流动」；hover 轻微 `translateY(-3px)`。
4. **按钮家族统一**：`intro-play-btn` 与 `detail-btn` 共用同一套 hover（图标微动 + 箭头/文案反馈）、`:active` 缩放。
5. **降级**：所有动效包在 `@media (prefers-reduced-motion: reduce)` 内 `transition: none`。

---

## 四、可直接落地的代码片段（推荐默认方案）

### 4.1 模板（`About.vue` 片段）
```html
<h1 class="page-title reveal-item">关于我<span class="title-tag">· 不正经版</span></h1>

<!-- 播放按钮：推荐默认文案 -->
<button class="intro-play-btn" type="button">
  <span class="play-ico">▶</span><span class="play-text">唤醒我的名片</span>
</button>

<!-- 状态标签：加直播小圆点 -->
<div class="mood reveal-item">
  <span class="mood-label"><i class="live-dot" aria-hidden="true"></i>脑子里的弹幕</span>
  ...
</div>

<!-- 爱好占位：更有人味的文案 -->
<li class="hobby hobby--placeholder reveal-item" aria-hidden="true">
  <span class="hobby-label">＋ 这一格，留给下次相遇</span>
</li>

<!-- 资料按钮：更口语 -->
<button class="detail-btn reveal-item" type="button" @click="panelOpen = true">
  翻开我的小档案 <span class="detail-arrow" aria-hidden="true">→</span>
</button>
```

### 4.2 样式（scoped，新增 / 覆盖）
```css
/* 标题角标 + 手绘下划线 */
.title-tag { font-size: .8rem; color: var(--color-text-muted); margin-left: .5rem; }
.page-title { position: relative; display: inline-block; }
.page-title::after {
  content: ""; position: absolute; left: 0; right: 0; bottom: -6px; height: 3px;
  background: linear-gradient(90deg, var(--color-accent), transparent);
  transform: scaleX(0); transform-origin: left; transition: transform .4s cubic-bezier(.22,.61,.36,1);
}
.page-title:hover::after { transform: scaleX(1); }

/* 直播小圆点（呼吸） */
.live-dot { display: inline-block; width: 7px; height: 7px; border-radius: 50%;
  background: var(--color-accent); margin-right: .4rem; animation: breathe 1.6s ease-in-out infinite; }
@keyframes breathe { 0%,100% { opacity: 1; } 50% { opacity: .3; } }

/* 播放按钮图标摆动 + 文案态 */
.play-ico { display: inline-block; transition: transform .25s ease; }
.intro-play-btn:hover .play-ico { animation: wiggle .6s ease-in-out infinite; }
@keyframes wiggle { 0%,100% { transform: rotate(0); } 25% { transform: rotate(-12deg); } 75% { transform: rotate(12deg); } }
.intro-play-btn.is-playing .play-ico { transform: rotate(90deg); }

/* 爱好占位：流动虚线 + 上浮 */
.hobby--placeholder { border: 1px dashed var(--color-border);
  background: repeating-linear-gradient(90deg, transparent, transparent 6px, color-mix(in srgb, var(--color-accent) 22%, transparent) 6px, color-mix(in srgb, var(--color-accent) 22%, transparent) 12px); }
.hobby--placeholder:hover { transform: translateY(-3px); }
```

---

## 五、实施建议

1. **先动按钮**：把 `intro-play-btn` 文案换成推荐的 `▶ 唤醒我的名片`，并加 `play-ico / play-text` 结构以支持 hover 摆动与「再看一遍」态。
2. **再批量换文案**：按上表把 `.mood-label`、`.hobby--placeholder`、`.detail-btn`、`.panel-h` 等替换为方案 A/B（文案建议在 `profile.json` 增字段，或组件内用 `const` 维护，便于统一改）。
3. **最后上交互**：下划线、呼吸圆点、流动虚线等纯 CSS 动效，统一加 `reduced-motion` 降级。
4. 我可下一步直接把这些改动写入 `About.vue` / `profile.json` 并构建验证。

> 注：本方案为「创意提案」，未改动任何源码；确认采用哪种语调 / 哪些元素后我再落地。
