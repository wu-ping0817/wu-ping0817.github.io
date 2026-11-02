<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { useContent } from '@/composables/useContent'
import CodeModal from '@/components/CodeModal.vue'
import VideoModal from '@/components/VideoModal.vue'

const { portfolio } = useContent()

/* ---------- 数据源 ---------- */
const rawItems = computed(() => portfolio.items)
const PER_PAGE = 6 // 默认每屏展示 6 份，突出核心
const DEFAULT_RING = 6 // 空数据占位演示用的环形槽位数（有真实数据时随当前页自适应）
const page = ref(0)
const pageCount = computed(() => Math.max(1, Math.ceil(all.value.length / PER_PAGE)))
const pageItems = computed(() =>
  all.value.slice(page.value * PER_PAGE, page.value * PER_PAGE + PER_PAGE)
)

const catMap = computed(() => {
  const m = {}
  portfolio.categories.forEach((c) => (m[c.id] = c))
  return m
})

/* =========================================================================
   导航栏：关联搜索 + 分类筛选
   「关联」体现在三处联动：
   1) 搜索词实时驱动每个分类 chip 的命中计数（0 命中的分类自动变暗禁用）；
   2) 选中分类作为搜索的范围约束（分类 × 关键词 双重过滤）；
   3) 任一条件变化都会过滤进入转盘的数据流，并复位分页/公转角度。
   ========================================================================= */
const query = ref('')
const activeCat = ref('') // '' = 全部分类

/* 单项匹配：标题 / 简介 / 分类名 / 技术栈，多关键词空格分隔为「与」关系 */
const matchItem = (it, q) => {
  const s = q.trim().toLowerCase()
  if (!s) return true
  const hay = [
    it.title,
    it.summary,
    (catMap.value[it.category] || {}).name || '',
    ...(it.tech || []),
  ]
    .join(' ')
    .toLowerCase()
  return s.split(/\s+/).every((w) => hay.includes(w))
}

/* 各分类在「当前搜索词」下的命中数（与选中分类无关 → 用于关联计数与禁用态） */
const catCounts = computed(() => {
  const m = {}
  for (const it of rawItems.value) {
    if (matchItem(it, query.value)) m[it.category] = (m[it.category] || 0) + 1
  }
  return m
})
const totalMatch = computed(() =>
  Object.values(catCounts.value).reduce((a, b) => a + b, 0)
)

/* 关联筛选：分类范围 × 搜索关键词，结果进入转盘数据流 */
const filtered = computed(() =>
  rawItems.value.filter(
    (it) =>
      (!activeCat.value || it.category === activeCat.value) &&
      matchItem(it, query.value)
  )
)
const isFiltering = computed(
  () => query.value.trim() !== '' || activeCat.value !== ''
)

/* 分页数据流的 `all` 即「筛选后」的作品（导航栏过滤直达转盘/分页） */
const all = computed(() => filtered.value)

/* ---------- 环形占位填充：保证转盘始终有足够卡片，避免单卡时公转动画异常 ----------
   - 真实作品数 < DEFAULT_RING 时，用骨架占位补齐到 DEFAULT_RING 张；
     否则 STEP=360°，单卡自旋一圈又回到原位，看起来像「原地打转 / 翻转」的动画异常。
   - 真实作品 >= DEFAULT_RING 时不补占位，环上全是真实卡片。
   - 占位卡复用 skeleton 渲染、不打开详情(openDetail 已拦截)、不出现任何操作按钮，
     内容留空即可（"占位什么都不需要写"）。 */
const ringPlaceholders = (count) =>
  Array.from({ length: count }, (_, i) => ({
    id: 'ph-' + (page.value * DEFAULT_RING + i),
    placeholder: true,
    category: '',
    title: '',
    summary: '',
    tech: [],
    repo: '',
    demo: '',
    script: '',
  }))
const displayItems = computed(() => {
  const real = pageItems.value
  if (real.length >= DEFAULT_RING) return real
  return [...real, ...ringPlaceholders(DEFAULT_RING - real.length)]
})

/* =========================================================================
   立体环形转盘（核心）—— 单一主视觉中心 + 沿纵深公转
   - N 张卡片（N 随当前页实际数量 1~6 自适应）刚性分布于绕「纵向轴」的水平圆环上，
     彼此相对位置恒定（整体公转，不自转）；
   - 整环微倾(rotateX TILT)并向纵深推入，公转时卡片沿纵深前后穿行（朝页面内推进 / 浮出），
     而非在二维平面内打转；
   - 任意时刻仅最前(θ≈0、正对观察者、最近、居中)的一张处于主视觉中心；其余因透视呈现不同
     状态——侧翼微倾、远端更虚更暗更小，作为背景层次存在，绝不共为主焦点；
   - 节奏放慢：缓动切换(TRANSITION) + 单件停留(DWELL)，停顿久、过渡平缓。
   ========================================================================= */
/* 环形卡片数随当前页实际数据量自适应：满 6 张则 6 槽位，不足则按实际数量铺满整圈，
   避免出现空缺区域；角间距随之动态均分（360° / 实际数量）。 */
const ringCount = computed(() => Math.max(1, displayItems.value.length))
const STEP = computed(() => 360 / ringCount.value)
const SPIN0 = 0

/* 环形几何（水平圆环 + 整环微倾 → 沿纵深穿行） */
const RING_R = 205 // 圆环半径(px)：左右展开幅度（略收紧，使整组更聚合统一）
const DEPTH = 192 // 公转 Z 深度幅度(px)：向页面内推进的纵深（越大空间感越强）
const FACE_TURN = 34 // 侧翼卡片微转向圆心角度(deg)，强化 coverflow 立体环抱感
const TILT = 22 // 整环倾角(deg)，由 CSS 应用在 .orbit 上

/* 尺寸层级规则：完全交由 CSS 透视自然产生 —— 卡片按 Z 深度排布于水平圆环，
   焦点卡始终位于最近处(Z=+DEPTH)，透视自然使其为 6 张中最大，越远(Z→-DEPTH)越小；
   不再叠加手动 scale，避免「双重缩放」导致远端被压得过小、景深过渡失真，
   从而严格符合透视规律、过渡自然协调。主次仍由光照(--lf)、景深模糊与 is-front 辉光强化。 */

/* 节奏：慢速、单件停留久、过渡平缓 */
const TRANSITION = 1600 // 切换到下一张的缓动时长(ms)
const DWELL = 3800 // 单件作品停留时长(ms)
const EASE = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2) // easeInOutCubic

/* 景深(DOF)模型：以最前(最近/正对/居中)卡片为唯一焦点平面，焦外随距焦距离柔和虚化 */
const DOF = {
  zone: 0.1, // 焦点附近清晰区（距焦比例 < zone 不虚化）
  maxBlur: 8, // 最远卡片最大虚化半径(px) —— 焦外虚化更明显
  ramp: 1.5, // 虚化强度曲线(>1 使焦外更突出、过渡更自然)
}

const spin = ref(SPIN0) // 整环当前旋转角（度）
const dragging = ref(false)
const hovering = ref(false)
const justDragged = ref(false)
const reduced = ref(false)

const orbitEl = ref(null)
const cardEls = ref([])
function setCardRef(el, i) {
  cardEls.value[i] = el
}

// 自动轮换暂停条件：拖拽 / 悬停 / 弹窗 / 降低动效。
// 注意：仅用于「空闲自动前进」，不阻断手动点击箭头 / 拖拽 / 分页触发的切换 ——
// 否则首次悬停后该暂停标志会永久为真，导致左右箭头彻底失效。
const autoPaused = computed(
  () => dragging.value || hovering.value || !!detail.value || code.value.open || reduced.value
)

/* ---------- 自动公转状态机：缓动切换 + 单件停留 ---------- */
let target = SPIN0 // 当前「已就位」角度基准（每次步进累加 STEP）
let tweening = false
let tweenFrom = SPIN0
let tweenTo = SPIN0
let tweenStart = 0
let holdUntil = 0 // 下一次自动步进的时间戳

function startTween(to) {
  tweenFrom = spin.value
  let delta = to - tweenFrom
  while (delta > 180) delta -= 360
  while (delta < -180) delta += 360
  tweenTo = tweenFrom + delta
  tweenStart = performance.now()
  tweening = true
}

/* ---------- 每一帧：计算每张卡角度/深度/景深并写入 DOM（直接操作，避免整树重渲染） ---------- */
function applyFrame() {
  const list = displayItems.value
  let frontIdx = 0
  let frontMax = -1
  for (let i = 0; i < list.length; i++) {
    const el = cardEls.value[i]
    if (!el) continue
    // 本卡在环上的绝对相位：θ = 当前 spin + 固定角间距
    const a = ((spin.value + i * STEP.value) * Math.PI) / 180
    // 水平圆环定位 + Z 深度起伏：a=0 时居中且最前（主视觉中心）
    const X = RING_R * Math.sin(a)
    const Z = DEPTH * Math.cos(a)
    const front = (Math.cos(a) + 1) / 2 // 1=最前(焦点/居中/最亮最大) 0=最远(背后)
    // 垂直基准：不再用 (1-front)*40 把后侧卡片往下压（那会让环像下垂吊床、透视失真），
    // 所有卡片保持同一基准高度，由透视自然产生「近大远小」；主视觉卡与侧/后卡同轴居中、不上下错位。
    const Y = 0
    const faceY = -Math.sin(a) * FACE_TURN // 侧翼卡片微倾(coverflow)；主视觉卡(a≈0)正对观察者
    // 尺寸层级完全交由 CSS 透视自然产生（近大远小、焦点恒为最近最大），
    // 不再叠加手动 scale —— 避免双重缩放导致远端被压成极小、整体失真。
    el.style.transform =
      `translate3d(${X.toFixed(1)}px, ${Y.toFixed(1)}px, ${Z.toFixed(1)}px) rotateY(${faceY.toFixed(1)}deg)`
    el.style.setProperty('--lf', front.toFixed(3)) // 动态光照因子
    el.style.zIndex = String(100 + Math.round(front * 100))
    // --- 景深(DOF)：以最前卡片为焦点平面，焦外随距焦距离柔和递增虚化 ---
    const d = 1 - front // 0=焦点 1=最远
    let blur = 0
    if (d > DOF.zone) {
      const t = (d - DOF.zone) / (1 - DOF.zone) // 距焦比例 0→1
      blur = Math.pow(t, DOF.ramp) * DOF.maxBlur
    }
    // 仅对明显远离焦点的卡片施加虚化（低于阈值保持 none，以保留前景卡的 3D 厚度）
    el.style.filter = blur > 0.6 ? `blur(${blur.toFixed(2)}px)` : 'none'
    // --- 大气透视(雾)：远处卡片渐隐入背景，强化前后层次（0=清晰 1=最雾） ---
    el.style.setProperty('--fog', (1 - Math.pow(front, 1.4)).toFixed(3))
    if (front > frontMax) {
      frontMax = front
      frontIdx = i
    }
  }
  // 标记唯一主视觉卡（仅最前一张），强化「同时只有一个焦点」
  for (let i = 0; i < cardEls.value.length; i++) {
    const el = cardEls.value[i]
    if (el) el.classList.toggle('is-front', i === frontIdx)
  }
}

/* ---------- 动画主循环：手动切换始终推进，空闲时按节奏自动前进 ---------- */
let raf = 0
function tick(now) {
  if (now === undefined) now = performance.now()
  // 手动触发的切换（箭头/拖拽/分页）始终推进，不受 hover 暂停影响 → 箭头始终生效
  if (tweening) {
    const t = Math.min(1, (now - tweenStart) / TRANSITION)
    spin.value = tweenFrom + (tweenTo - tweenFrom) * EASE(t)
    if (t >= 1) {
      tweening = false
      holdUntil = now + DWELL
    }
  } else if (!autoPaused.value && now >= holdUntil) {
    // 空闲且未暂停时自动前进到下一张（hover/拖拽/弹窗时暂停自动轮换）
    target += STEP.value
    startTween(target)
  }
  applyFrame()
  raf = requestAnimationFrame(tick)
}

/* ---------- 拖拽公转 ---------- */
let startX = 0
let startSpin = 0
let moved = 0
function onDown(e) {
  dragging.value = true
  moved = 0
  startX = e.clientX
  startSpin = spin.value
  holdUntil = Infinity // 拖拽期间暂停自动步进
}
function onMove(e) {
  if (!dragging.value) return
  const dx = e.clientX - startX
  moved = Math.max(moved, Math.abs(dx))
  spin.value = startSpin + dx * 0.4
}
function onUp() {
  if (!dragging.value) return
  dragging.value = false
  justDragged.value = moved > 6
  // 吸附到最近的「卡片正前」角度，使某张卡回到主视觉中心
  const snapped = Math.round(spin.value / STEP.value) * STEP.value
  target = snapped
  startTween(snapped)
}

// 指针离开舞台：解除 hover 暂停（修复「首次悬停后暂停标志永久为真 → 箭头失效」）
function onPointerLeave() {
  hovering.value = false
  onUp()
}

/* ---------- 箭头：步进公转 ---------- */
function stepDir(dir) {
  target += dir * STEP.value
  startTween(target)
}

/* ---------- 分页 ---------- */
function setPage(p) {
  if (p < 0 || p >= pageCount.value || p === page.value) return
  page.value = p
  spin.value = SPIN0 // 复位：0 号卡回到主视觉中心
  target = SPIN0
  tweening = false
  holdUntil = performance.now() + DWELL
}
watch(page, () => (cardEls.value = []))

/* 筛选条件变化：复位分页与公转，避免环上卡片组合切换时停留在中途角度 */
watch([query, activeCat], () => {
  if (page.value > pageCount.value - 1) {
    page.value = Math.max(0, pageCount.value - 1)
  }
  spin.value = SPIN0
  target = SPIN0
  tweening = false
  holdUntil = performance.now() + DWELL
})

/* ---------- 详情弹窗 ---------- */
const detail = ref(null)
function openDetail(it) {
  if (it.placeholder) return // 占位组件不打开详情
  if (justDragged.value) {
    justDragged.value = false
    return
  }
  detail.value = it
}
function closeDetail() {
  detail.value = null
}

// 脚本预览（复用 CodeModal）
const code = ref({ open: false, title: '', src: '', lang: 'bash' })
function openCode(it) {
  // it.script 已由 useContent 解析为最终资源 URL（含 base，如 /wu-ping0817/assets/...sh；
  // 或被内联为 data: 的极小文件）。已是完整 URL（http(s)://、//、data:）或站点绝对路径（/）则原样使用，
  // 否则补 base 兜底。
  const resolved =
    it.script.startsWith('http') ||
    it.script.startsWith('//') ||
    it.script.startsWith('data:') ||
    it.script.startsWith('/')
      ? it.script
      : import.meta.env.BASE_URL + it.script
  code.value = {
    open: true,
    title: it.title,
    lang: it.scriptLang || 'bash',
    src: resolved,
  }
}

// 演示视频弹层（VideoModal）：卡片/详情的「▶ 演示」按钮触发；
// it.video 由 useContent 解析为资源 URL，文件未放入时字段不存在、按钮自动隐藏
const video = ref({ open: false, title: '', src: '' })
function openVideo(it) {
  if (!it.video) return
  video.value = { open: true, title: it.title, src: it.video }
}

onMounted(() => {
  reduced.value = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  holdUntil = performance.now() + DWELL
  raf = requestAnimationFrame(tick)
})
onBeforeUnmount(() => cancelAnimationFrame(raf))
</script>

<template>
  <section class="screen portfolio">
    <header class="head">
      <h1 class="page-title">这里没有大作</h1>
    </header>

    <!-- 作品导航栏：关联搜索 + 分类筛选（搜索词驱动分类计数，分类约束搜索范围） -->
    <nav class="works-nav" aria-label="作品导航与筛选">
      <div class="wn-search">
        <svg
          class="wn-ico"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          aria-hidden="true"
        >
          <circle cx="11" cy="11" r="7"></circle>
          <path d="M20 20l-3.8-3.8"></path>
        </svg>
        <input
          v-model="query"
          class="wn-input"
          type="search"
          placeholder="搜索作品、技术栈或分类…"
          aria-label="搜索作品"
        />
        <button
          v-if="query"
          class="wn-clear"
          type="button"
          aria-label="清除搜索"
          @click="query = ''"
        >
          ✕
        </button>
      </div>
      <div class="wn-cats" aria-label="按分类筛选">
        <button
          class="wn-cat"
          type="button"
          :class="{ active: activeCat === '' }"
          :aria-pressed="activeCat === ''"
          @click="activeCat = ''"
        >
          全部 <span class="wn-count">{{ totalMatch }}</span>
        </button>
        <button
          v-for="c in portfolio.categories"
          :key="c.id"
          class="wn-cat"
          type="button"
          :class="{ active: activeCat === c.id, dim: (catCounts[c.id] || 0) === 0 }"
          :disabled="(catCounts[c.id] || 0) === 0"
          :aria-pressed="activeCat === c.id"
          @click="activeCat = activeCat === c.id ? '' : c.id"
        >
          {{ c.name }} <span class="wn-count">{{ catCounts[c.id] || 0 }}</span>
        </button>
      </div>
      <p v-if="query && all.length === 0" class="wn-empty" role="status">
        没有匹配的作品，换个关键词试试
      </p>
    </nav>

    <div class="stage-wrap fx-static">
      <button class="ring-nav" type="button" aria-label="逆时针旋转" @click="stepDir(-1)">‹</button>

      <div
        class="viewport"
        :class="{ dragging }"
        @pointerdown="onDown"
        @pointermove="onMove"
        @pointerup="onUp"
        @pointerleave="onPointerLeave"
        @pointerenter="hovering = true"
        @pointercancel="onUp"
      >
        <!-- 纵深辉光：强化「向页面内」的灭点感（隐形中心不画实体） -->
        <div class="depth-glow" aria-hidden="true"></div>

        <!-- 倾斜圆盘轨道：圆心位于页面后方，整体绕 Z 轴公转 -->
        <div class="orbit" ref="orbitEl">
          <!-- 轨道引导椭圆（位于轨道平面内，随透视呈椭圆），极淡 -->
          <div class="orbit-guide" aria-hidden="true"></div>

          <article
            v-for="(it, i) in displayItems"
            :key="it.id"
            class="card"
            :class="{ placeholder: it.placeholder }"
            :ref="(el) => setCardRef(el, i)"
            @click="openDetail(it)"
          >
            <!-- 立体卡片：六面体（前/后/四侧边），径向刚性朝向，随轨道公转不自转 -->
            <div class="card__vol">
              <div class="card__face front">
                <!-- 占位骨架：缺数据时以骨架块填充，保持布局结构与动画一致 -->
                <template v-if="it.placeholder">
                  <span class="skel skel-cat"></span>
                  <span class="skel skel-title"></span>
                  <span class="skel skel-line"></span>
                  <span class="skel skel-line short"></span>
                  <div class="skel skel-tech">
                    <i></i><i></i><i></i>
                  </div>
                </template>
                <template v-else>
                <div class="card-top">
                  <span class="card-cat">{{ (catMap[it.category] || {}).name || '作品' }}</span>
                  <span v-if="it.script" class="card-lang">{{ it.scriptLang || 'sh' }}</span>
                </div>
                <h3 class="card-title">{{ it.title }}</h3>
                <p class="card-summary">{{ it.summary }}</p>
                <div class="tech">
                  <span v-for="t in it.tech" :key="t" class="chip">{{ t }}</span>
                </div>
                <div class="links">
                  <a
                    v-if="it.repo"
                    :href="it.repo"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="lnk"
                    @click.stop
                    >源码 ↗</a
                  >
                  <a
                    v-if="it.demo"
                    :href="it.demo"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="lnk lnk--primary"
                    @click.stop
                    >在线演示 ↗</a
                  >
                  <button
                    v-if="it.script"
                    type="button"
                    class="lnk lnk--cta"
                    @click.stop="openCode(it)"
                  >
                    脚本&lt;/&gt;
                  </button>
                  <button
                    v-if="it.video"
                    type="button"
                    class="lnk lnk--ghost"
                    title="播放演示视频"
                    aria-label="播放演示视频"
                    @click.stop="openVideo(it)"
                  >
                    ▶
                  </button>
                  <a
                    v-if="it.file"
                    :href="it.file"
                    download
                    class="lnk lnk--ghost"
                    title="下载作品文件"
                    aria-label="下载作品文件"
                    @click.stop
                    >⬇</a
                  >
                </div>
                </template>
              </div>
              <div class="card__face back" aria-hidden="true"></div>
              <div class="card__edge left" aria-hidden="true"></div>
              <div class="card__edge right" aria-hidden="true"></div>
              <div class="card__edge top" aria-hidden="true"></div>
              <div class="card__edge bottom" aria-hidden="true"></div>
              <!-- 动态受光层：随公转角在左上生成高光，体现立体与光照 -->
              <div class="card__light" aria-hidden="true"></div>
              <!-- 大气透视雾层：远处卡片渐隐入背景，强化纵深（透明于最近卡） -->
              <div class="card__fog" aria-hidden="true"></div>
            </div>
          </article>
        </div>
      </div>

      <button class="ring-nav" type="button" aria-label="顺时针旋转" @click="stepDir(1)">›</button>
    </div>

    <!-- 分页：涵盖全部作品，同页内切换 -->
    <nav class="pager" aria-label="作品分页">
      <span class="pg-info">{{ isFiltering ? '命中' : '共' }} {{ all.length }} 件 · 第 {{ page + 1 }}/{{ pageCount }} 页</span>
      <div class="pg-btns">
        <button
          class="pg-btn"
          type="button"
          :disabled="page === 0"
          aria-label="上一页"
          @click="setPage(page - 1)"
        >
          ‹
        </button>
        <button
          v-for="p in pageCount"
          :key="p"
          class="pg-dot"
          type="button"
          :class="{ active: p - 1 === page }"
          :aria-label="`第 ${p} 页`"
          :aria-current="p - 1 === page ? 'page' : undefined"
          @click="setPage(p - 1)"
        >
          {{ p }}
        </button>
        <button
          class="pg-btn"
          type="button"
          :disabled="page === pageCount - 1"
          aria-label="下一页"
          @click="setPage(page + 1)"
        >
          ›
        </button>
      </div>
    </nav>

    <!-- 详情弹窗 -->
    <Teleport to="body">
      <div v-if="detail" class="dt-mask" @click.self="closeDetail">
        <div class="dt-panel" role="dialog" aria-modal="true" :aria-label="`作品详情：${detail.title}`">
          <button class="dt-close" type="button" aria-label="关闭" @click="closeDetail">✕</button>
          <span class="dt-cat">{{ (catMap[detail.category] || {}).name || '作品' }}</span>
          <h2 class="dt-title">{{ detail.title }}</h2>
          <p class="dt-summary">{{ detail.summary }}</p>
          <div v-if="detail.tech && detail.tech.length" class="tech dt-tech">
            <span v-for="t in detail.tech" :key="t" class="chip">{{ t }}</span>
          </div>
          <div class="dt-actions">
            <a
              v-if="detail.repo"
              :href="detail.repo"
              target="_blank"
              rel="noopener noreferrer"
              class="dt-link"
              @click.stop
              >查看源码 ↗</a
            >
            <a
              v-if="detail.demo"
              :href="detail.demo"
              target="_blank"
              rel="noopener noreferrer"
              class="dt-link dt-link--primary"
              @click.stop
              >在线演示 ↗</a
            >
            <button
              v-if="detail.script"
              type="button"
              class="dt-link dt-link--primary"
              @click.stop="openCode(detail)"
            >
              查看脚本 &lt;/&gt;
            </button>
            <button
              v-if="detail.video"
              type="button"
              class="dt-link"
              @click.stop="openVideo(detail)"
            >
              ▶ 演示视频
            </button>
            <a v-if="detail.file" :href="detail.file" download class="dt-link" @click.stop
              >⬇ 下载</a
            >
          </div>
        </div>
      </div>
    </Teleport>

    <CodeModal
      :open="code.open"
      :title="code.title"
      :src="code.src"
      :lang="code.lang"
      @close="code.open = false"
    />

    <!-- 演示视频弹层 -->
    <VideoModal
      :open="video.open"
      :title="video.title"
      :src="video.src"
      @close="video.open = false"
    />
  </section>
</template>

<style scoped>
.portfolio {
  text-align: left;
  display: flex;
  flex-direction: column;
  align-items: center;
  /* 垂直居中于可用视口：.content（DefaultLayout）是 min-height:100dvh 的纵向 flex 容器，
     margin auto 会吸收剩余空间，使「标题+舞台+分页」整块在任意窗口高度下垂直居中——
     否则页面内容顶端锚定，高窗口下舞台偏上（这正是「相对窗口偏上」在面板内修复后仍残留的来源）。
     用 margin auto 而非 justify-content:center：内容高于视口时 auto 退化为 0，
     顶部不会被裁剪、可正常滚动（safe centering）。 */
  margin-top: auto;
  margin-bottom: auto;
  /* 说明：此前曾在此加 padding-top:7rem 试图纠正「卡片偏上」，
     后经 CDP 实测定位真正根因是 .card__light/.card__fog 缺失绝对定位、
     负 margin 折叠把卡面上拖半张卡（见 .card__face 规则处注释），
     故此处还原为全局 .screen 的统一节奏，不再做页面级补偿。 */
}
.head {
  margin-bottom: 1.4rem;
  text-align: center;
}
.page-title {
  margin: 0 0 0.5rem;
  font-size: 2rem;
}

/* ---------- 作品导航栏：关联搜索 + 分类筛选 ----------
   玻璃拟态导航条，与舞台面板/旋转箭头同一材质语言：
   半透明 surface + blur + 内高光，选中态用 accent 实底（与分页 active 一致）。 */
.works-nav {
  width: 100%;
  max-width: 760px; /* 与舞台面板 .viewport 同宽，视觉对齐 */
  margin: 0 auto 1.2rem;
  padding: 0.55rem 0.7rem;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.55rem 0.75rem;
  border-radius: 14px;
  background: color-mix(in srgb, var(--color-bg-surface) 58%, transparent);
  border: 1px solid color-mix(in srgb, var(--color-border) 80%, transparent);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  box-shadow:
    inset 0 1px 0 color-mix(in srgb, #ffffff 6%, transparent),
    0 16px 44px -26px rgba(0, 0, 0, 0.65);
}
.wn-search {
  position: relative;
  flex: 1 1 220px;
  min-width: 200px;
  display: flex;
  align-items: center;
}
.wn-ico {
  position: absolute;
  left: 0.72rem;
  width: 15px;
  height: 15px;
  color: var(--color-text-muted);
  pointer-events: none;
}
.wn-input {
  width: 100%;
  padding: 0.5rem 2.2rem;
  font-family: inherit;
  font-size: 0.85rem;
  color: var(--color-text-on-surface);
  background: color-mix(in srgb, var(--color-bg-elevated) 72%, transparent);
  border: 1px solid var(--color-border);
  border-radius: 999px;
  outline: none;
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}
.wn-input::placeholder {
  color: var(--color-text-muted);
  opacity: 0.72;
}
.wn-input:focus {
  border-color: var(--color-accent);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--color-accent) 20%, transparent);
}
/* 用自定义清除按钮，隐藏原生 ✕（各浏览器样式不一致） */
.wn-input::-webkit-search-cancel-button {
  display: none;
}
.wn-clear {
  position: absolute;
  right: 0.45rem;
  width: 22px;
  height: 22px;
  display: grid;
  place-items: center;
  font-size: 0.72rem;
  line-height: 1;
  border: none;
  border-radius: 50%;
  cursor: pointer;
  color: var(--color-text-muted);
  background: color-mix(in srgb, var(--color-border) 55%, transparent);
  transition: color 0.2s ease, background 0.2s ease;
}
.wn-clear:hover {
  color: var(--color-text-on-surface);
  background: var(--color-border);
}
.wn-cats {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}
.wn-cat {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-family: inherit;
  font-size: 0.78rem;
  font-weight: 600;
  padding: 0.32rem 0.72rem;
  border-radius: 999px;
  cursor: pointer;
  color: var(--color-text-on-surface);
  background: color-mix(in srgb, var(--color-bg-elevated) 75%, transparent);
  border: 1px solid var(--color-border);
  transition: border-color 0.2s ease, color 0.2s ease, background 0.2s ease,
    opacity 0.2s ease;
}
.wn-cat:hover:not(:disabled):not(.active) {
  border-color: var(--color-accent);
  color: var(--color-link);
}
.wn-cat:focus-visible {
  outline: 2px solid var(--color-focus);
  outline-offset: 2px;
}
.wn-cat.active {
  background: var(--color-accent);
  border-color: transparent;
  color: var(--color-text-on-accent);
}
/* 0 命中的分类：变暗禁用 —— 搜索词与分类导航的「关联」可视化 */
.wn-cat.dim,
.wn-cat:disabled {
  cursor: not-allowed;
  opacity: 0.38;
}
.wn-count {
  font-size: 0.68rem;
  font-weight: 700;
  padding: 0.05rem 0.4rem;
  border-radius: 999px;
  font-variant-numeric: tabular-nums;
  background: color-mix(in srgb, currentColor 14%, transparent);
}
.wn-empty {
  flex-basis: 100%;
  margin: 0;
  padding: 0.05rem 0.25rem 0;
  font-size: 0.78rem;
  color: var(--color-text-muted);
}
@media (max-width: 560px) {
  .wn-search {
    flex-basis: 100%;
  }
}

/* ---------- 占位骨架（缺少真实数据时使用，风格与真实卡片一致） ---------- */
.card.placeholder .card__face.front {
  /* 与真实卡片一致地垂直居中内容块（被下方 .card__face.front 的 justify-content:center 统一约束），
     使骨架视觉重心居中，避免只堆在上半部显得「偏上」 */
  gap: 0.7rem;
}
.skel {
  display: block;
  border-radius: 6px;
  background: linear-gradient(
    100deg,
    color-mix(in srgb, var(--color-bg-elevated) 60%, transparent) 30%,
    color-mix(in srgb, var(--color-border) 80%, #fff 10%) 50%,
    color-mix(in srgb, var(--color-bg-elevated) 60%, transparent) 70%
  );
  background-size: 200% 100%;
  animation: skelShine 1.4s ease-in-out infinite;
}
.skel-cat { width: 38%; height: 0.7rem; }
.skel-title { width: 70%; height: 1.05rem; border-radius: 8px; }
.skel-line { width: 100%; height: 0.62rem; }
.skel-line.short { width: 62%; }
.skel-tech {
  display: flex;
  gap: 0.35rem;
}
.skel-tech i {
  width: 2.4rem;
  height: 0.95rem;
  border-radius: 999px;
  background: color-mix(in srgb, var(--color-bg-elevated) 80%, var(--color-border));
  animation: skelShine 1.4s ease-in-out infinite;
  background-size: 200% 100%;
}
@keyframes skelShine {
  from { background-position: 200% 0; }
  to { background-position: -200% 0; }
}
@media (prefers-reduced-motion: reduce) {
  .skel,
  .skel-tech i {
    animation: none;
  }
}

/* ---------- 公转舞台 ---------- */
.stage-wrap {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  width: 100%;
  justify-content: center;
}
.viewport {
  position: relative;
  flex: 1;
  max-width: 760px;
  height: 470px;
  /* 透视：观察者位于屏幕外，近大远小；视点略偏下，对齐已下移的环形舞台灭点，
     使整组在纵深推进时纵向居中、与标题/分页间距协调。
     透视值压低 → 前后卡片尺寸差更大，纵深与空间感更强。 */
  perspective: 820px;
  perspective-origin: 50% 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  touch-action: none;
  cursor: grab;
  /* —— 新舞台背景：与全站暗色 + 淡蓝辅色协调的「玻璃舞台」面板 ——
     两层径向渐变：顶部 accent 辉光（呼应纵深远点）+ 底部 elevated 微光，
     再叠一层极淡 surface 薄雾，半透明让全站粒子背景透出，保持空间连贯。 */
  border-radius: 22px;
  background:
    radial-gradient(
      130% 120% at 50% 26%,
      color-mix(in srgb, var(--color-accent) 9%, transparent) 0%,
      transparent 58%
    ),
    radial-gradient(
      120% 130% at 50% 110%,
      color-mix(in srgb, var(--color-bg-elevated) 55%, transparent) 0%,
      transparent 60%
    ),
    color-mix(in srgb, var(--color-bg-surface) 20%, transparent);
  border: 1px solid color-mix(in srgb, var(--color-border) 80%, transparent);
  box-shadow:
    inset 0 1px 0 color-mix(in srgb, #ffffff 8%, transparent),
    inset 0 0 70px -22px color-mix(in srgb, var(--color-accent) 26%, transparent),
    0 36px 90px -50px rgba(0, 0, 0, 0.7);
}
.viewport:active {
  cursor: grabbing;
}

/* 暗角：聚焦视线到中心舞台，强化「镜头」纵深感（不挡交互）；随舞台圆角裁切 */
.viewport::after {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  pointer-events: none;
  background: radial-gradient(
    ellipse 72% 62% at 50% 45%,
    transparent 60%,
    rgba(3, 7, 15, 0.34) 100%
  );
  z-index: 6;
}

/* 纵深辉光：在圆心(隐形)处放一团由核心向外渐隐的辉光，暗示灭点与「向页面里」的纵深 */
.depth-glow {
  position: absolute;
  left: 50%;
  top: 50%;
  width: 520px;
  height: 520px;
  transform: translate(-50%, -50%);
  background: radial-gradient(
    circle at center,
    color-mix(in srgb, var(--color-accent) 22%, transparent) 0%,
    color-mix(in srgb, var(--color-accent) 7%, transparent) 30%,
    transparent 62%
  );
  filter: blur(6px);
  pointer-events: none;
  z-index: 0;
}

/* 公转上下文：建立 preserve-3d 三维空间，整组向页面后方推入(负 Z)。
   垂直方向：perspective-origin 居中(50% 50%)，所有卡片同轴等高（applyFrame 已不再下压后侧卡），
   整组的纵向落点由唯一变量 translateY(= --orbit-y) 控制，默认 0 = 舞台中线（焦点卡与侧/后卡同心居中）。
   卡片绕纵向轴(Y)公转，公转时 Z 深度在 ±DEPTH 间起伏（朝页面内推进/浮出），
   沿主视角纵深方向穿行，而非在二维平面里打转；具体位置/深度/朝向由 JS 逐帧写入。 */
.orbit {
  --R: 205px; /* 轨道引导椭圆半径（装饰用，与 JS 中 RING_R 保持一致） */
  /* 整组在舞台内垂直居中：translateY 为唯一纵向落点（默认 0 = 舞台中线）。
     若预览后主卡整体仍偏高/偏低，只改 --orbit-y（每 ±6px 主卡约 ±7px），其它无需动。 */
  --orbit-y: 0px;
  position: absolute;
  top: 50%;
  left: 50%;
  width: 0;
  height: 0;
  transform-style: preserve-3d;
  transform: translateZ(-30px) translateY(var(--orbit-y));
  will-change: transform;
}

/* 轨道引导椭圆：位于轨道平面内的正圆，透视后呈椭圆，极淡，仅作空间引导 */
.orbit-guide {
  position: absolute;
  top: 50%;
  left: 50%;
  width: calc(2 * var(--R));
  height: calc(2 * var(--R));
  margin-left: calc(-1 * var(--R));
  margin-top: calc(-1 * var(--R));
  border-radius: 50%;
  border: 1px dashed color-mix(in srgb, var(--color-border) 75%, var(--color-accent));
  opacity: 0.22;
  pointer-events: none;
}

/* 卡片外层：位置/深度/朝向由 JS 在 applyFrame 逐帧写入（billboard + Z 深度公转）。
   默认 transform 为朝前兜底，避免 JS 未执行时卡片侧对屏幕只剩薄边而「看不见」。 */
.card {
  --w: 168px; /* 略增大，提升正文字号可读性 */
  --h: 208px; /* 收紧高度：使卡片盒更贴合内容、减少内部留白（占位骨架不再只填满约一半） */
  --t: 18px; /* 立体厚度 */
  --th: calc(var(--t) / 2);
  --radius: 18px; /* 统一圆角 */
  position: absolute;
  top: 50%;
  left: 50%;
  width: var(--w);
  height: var(--h);
  margin: calc(var(--h) / -2) 0 0 calc(var(--w) / -2);
  transform-style: preserve-3d;
  transform: translate3d(0, 0, 0); /* 兜底：正面朝观察者 */
  cursor: pointer;
  will-change: transform, filter;
}

/* 立体核心：六面体容器，所有面在 3D 空间中成立 */
.card__vol {
  position: relative;
  width: var(--w);
  height: var(--h);
  transform-style: preserve-3d;
  transition: transform 0.45s cubic-bezier(0.16, 1, 0.3, 1);
}

/* 六个面 + 受光层/雾层：统一绝对定位于 vol 中心。
   ⚠️ card__light/card__fog 必须在此获得 position:absolute——否则它们是静态流内元素，
   其 margin-top:-半卡高 会通过无 border/padding 的 vol 向上折叠(margin collapse)，
   把整个 vol 连同所有面片拖高半张卡（这正是「卡片偏上」的真正根因）。 */
.card__face,
.card__edge,
.card__light,
.card__fog {
  position: absolute;
  left: 50%;
  top: 50%;
  border-radius: var(--radius);
}
.card__face.front,
.card__face.back {
  width: var(--w);
  height: var(--h);
  margin-left: calc(var(--w) / -2);
  margin-top: calc(var(--h) / -2);
}
.card__edge.left,
.card__edge.right {
  width: var(--t);
  height: var(--h);
  margin-left: calc(var(--t) / -2);
  margin-top: calc(var(--h) / -2);
}
.card__edge.top,
.card__edge.bottom {
  width: var(--w);
  height: var(--t);
  margin-left: calc(var(--w) / -2);
  margin-top: calc(var(--t) / -2);
}
.card__face.front {
  transform: translateZ(var(--th));
  display: flex;
  flex-direction: column;
  /* 内容块在卡片内垂直居中：真实卡与占位卡统一，使「视觉重心」居中，
     消除因 summary 撑满、文字堆在上半部而显得「偏上」的错觉 */
  justify-content: center;
  gap: 0.5rem;
  padding: 1rem;
  /* 玻璃正面：上亮下暗竖向渐变营造体积，半透让舞台辉光微微透出 */
  background:
    linear-gradient(
      158deg,
      color-mix(in srgb, var(--color-bg-surface) 90%, #ffffff 10%) 0%,
      var(--color-bg-surface) 48%,
      color-mix(in srgb, var(--color-bg-surface) 86%, #000000 14%) 100%
    );
  color: var(--color-text-on-surface);
  /* 描边随光照增亮：近处微微泛 accent，远处回落到基础边框 */
  border: 1px solid color-mix(in srgb, var(--color-border) 82%, var(--color-accent) calc(26% * var(--lf, 1) + 6%));
  /* 分层投影：内高光(玻璃顶缘) + 内暗边(底缘) + 环境落影 + 随光照增强的 accent 辉光 */
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.08),
    inset 0 -1px 0 rgba(0, 0, 0, 0.2),
    0 24px 50px -18px rgba(0, 0, 0, 0.55),
    0 12px 30px -12px color-mix(in srgb, var(--color-accent) calc(46% * var(--lf, 1)), transparent);
  /* 动态受光：正前最亮、正后最暗，随公转平滑变化（brightness 不破坏 3D） */
  filter: brightness(calc(0.55 + 0.5 * var(--lf, 1)));
  /* 兜底：内容超出卡面时按圆角裁切，不允许溢出到 3D 卡外穿帮 */
  overflow: hidden;
  backface-visibility: hidden;
}
.card__face.back {
  transform: rotateY(180deg) translateZ(var(--th));
  background: var(--color-bg-elevated);
  border: 1px solid var(--color-border);
}
/* 侧边材质：上缘受光偏亮、下缘背光偏暗，左右随厚度收口并带圆柱状明暗渐变，形成真实体量 */
.card__edge {
  background: var(--color-bg-elevated);
  border: 1px solid color-mix(in srgb, var(--color-border) 65%, #000);
}
.card__edge.top {
  transform: rotateX(90deg) translateZ(calc(var(--h) / 2));
  background: linear-gradient(180deg, color-mix(in srgb, var(--color-bg-elevated) 80%, #fff 20%),
    color-mix(in srgb, var(--color-bg-elevated) 66%, #fff 14%));
}
.card__edge.bottom {
  transform: rotateX(-90deg) translateZ(calc(var(--h) / 2));
  background: linear-gradient(180deg, color-mix(in srgb, var(--color-bg-elevated) 64%, #000 28%),
    color-mix(in srgb, var(--color-bg-elevated) 58%, #000 36%));
}
.card__edge.left {
  transform: rotateY(-90deg) translateZ(calc(var(--w) / 2));
  background: linear-gradient(90deg, color-mix(in srgb, var(--color-bg-elevated) 56%, #000 22%), var(--color-bg-elevated));
}
.card__edge.right {
  transform: rotateY(90deg) translateZ(calc(var(--w) / 2));
  background: linear-gradient(90deg, var(--color-bg-elevated), color-mix(in srgb, var(--color-bg-elevated) 56%, #000 22%));
}

/* 动态受光高光：左上方一道柔光，强度随公转角(--lf)变化 */
.card__light {
  width: var(--w);
  height: var(--h);
  margin-left: calc(var(--w) / -2);
  margin-top: calc(var(--h) / -2);
  transform: translateZ(calc(var(--th) + 0.5px));
  border-radius: var(--radius);
  pointer-events: none;
  background: linear-gradient(
    135deg,
    rgba(255, 255, 255, calc(0.32 * var(--lf, 1))) 0%,
    rgba(255, 255, 255, 0) 52%
  );
}

/* 大气透视雾层：随 --fog(0=最近清晰 → 1=最远)渐隐入背景，强化前后层次与纵深 */
.card__fog {
  width: var(--w);
  height: var(--h);
  margin-left: calc(var(--w) / -2);
  margin-top: calc(var(--h) / -2);
  transform: translateZ(calc(var(--th) + 1px));
  border-radius: var(--radius);
  pointer-events: none;
  background: var(--dof-fog, var(--color-bg, #0a0f1c));
  opacity: calc(var(--fog, 0) * 0.5);
}

/* 常规正面描边/辉光已统一在上方 .card__face.front 中按 --lf 处理；
   以下仅保留 is-front(主视觉) 与 hover(悬停) 的覆盖规则。 */

/* 唯一主视觉卡：仅最前(居中/最近)的一张获得此标记，强化「同一时刻只有一个焦点」 */
.card.is-front {
  z-index: 300;
}
.card.is-front .card__face.front {
  border-color: color-mix(in srgb, var(--color-accent) 60%, var(--color-border));
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.1),
    inset 0 -1px 0 rgba(0, 0, 0, 0.22),
    0 30px 60px -16px rgba(0, 0, 0, 0.5),
    0 16px 44px -10px color-mix(in srgb, var(--color-accent) 78%, transparent);
}
/* 主视觉卡轻微前推，进一步拉开与背景层次的纵深差 */
.card.is-front .card__vol {
  transform: translateZ(20px);
}

/* 悬停翻起检视：把该卡向前推并轻微转动，露出厚度与侧边（用户主动交互，非公转自转） */
.viewport:not(.dragging) .card:hover .card__vol {
  transform: translateZ(34px) rotateX(-9deg) rotateY(12deg);
}
.card:hover {
  z-index: 200;
}
/* 悬停时正面强化：accent 描边 + 抬升辉光 + 玻璃内高光，给出清晰可辨的悬停反馈 */
.viewport:not(.dragging) .card:hover .card__face.front {
  border-color: color-mix(in srgb, var(--color-accent) 70%, var(--color-border));
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.1),
    inset 0 -1px 0 rgba(0, 0, 0, 0.22),
    0 34px 66px -18px rgba(0, 0, 0, 0.6),
    0 18px 42px -12px color-mix(in srgb, var(--color-accent) 62%, transparent);
}
.card:focus-visible {
  outline: 2px solid var(--color-focus);
  outline-offset: 4px;
}

.card-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.4rem;
}
.card-cat {
  font-size: 0.66rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-accent-strong, var(--color-accent));
  min-width: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.card-lang {
  flex: none;
  font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
  font-size: 0.6rem;
  letter-spacing: 0.02em;
  padding: 0.12rem 0.42rem;
  border-radius: 6px;
  color: var(--color-accent-strong, var(--color-accent));
  background: color-mix(in srgb, var(--color-accent) 14%, transparent);
  border: 1px solid color-mix(in srgb, var(--color-accent) 30%, transparent);
}
.card-title {
  margin: 0;
  font-size: 1.12rem;
  font-weight: 700;
  letter-spacing: 0.01em;
  line-height: 1.25;
}
.card-summary {
  margin: 0;
  font-size: 0.8rem;
  line-height: 1.6;
  color: var(--color-text-muted);
  /* 单行截断：168×208 小卡的内容区仅约 174px 高，卡片定位是「预告片」——
     完整摘要与全部操作在详情弹窗。注意：line-clamp 自带 overflow:hidden 会使该
     flex 子项的自动最小尺寸归零，一旦内容总高溢出，摘要会被 flex 收缩压成 0 高度
     （隐形）——因此必须让内容总高真正 ≤ 内容区，而不是依赖收缩。 */
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.tech {
  display: flex;
  gap: 0.4rem;
  flex-wrap: wrap;
}
/* 卡面内的 tech：单行展示 + 渐隐裁切（详情弹窗的 .tech 保持可换行完整展示） */
.card__face.front .tech {
  flex-wrap: nowrap;
  overflow: hidden;
  -webkit-mask-image: linear-gradient(90deg, #000 78%, transparent 98%);
  mask-image: linear-gradient(90deg, #000 78%, transparent 98%);
}
.chip {
  font-size: 0.72rem;
  padding: 0.16rem 0.55rem;
  border-radius: 999px;
  background: var(--color-bg-elevated);
  border: 1px solid var(--color-border);
  color: var(--color-text-on-surface);
}
.links {
  display: flex;
  gap: 0.3rem;
  padding-top: 0.3rem;
  flex-wrap: wrap;
}
.lnk {
  font-size: 0.78rem;
  font-weight: 600;
  color: var(--color-text-muted);
  border: none;
  background: none;
  padding: 0;
  cursor: pointer;
  border-bottom: 1px solid transparent;
  transition: color 0.2s ease;
  font-family: inherit;
}
.lnk:hover {
  color: var(--color-link);
  text-decoration: none;
}
.lnk--primary {
  color: var(--color-accent-strong, var(--color-accent));
}
/* 主操作按钮（脚本类作品唯一/核心动作）：实心 accent 胶囊，弱化多余边框、突出可点击性 */
.lnk--cta {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  font-size: 0.72rem;
  font-weight: 700;
  padding: 0.3rem 0.6rem;
  border: none;
  border-radius: 999px;
  color: #fff;
  background: var(--color-accent);
  text-decoration: none;
  box-shadow: 0 6px 16px -6px color-mix(in srgb, var(--color-accent) 70%, transparent);
  transition: transform 0.15s ease, box-shadow 0.2s ease, filter 0.2s ease;
}
.lnk--cta:hover {
  color: #fff;
  filter: brightness(1.08);
  transform: translateY(-1px);
  box-shadow: 0 10px 22px -8px color-mix(in srgb, var(--color-accent) 80%, transparent);
}
/* 次操作胶囊（演示视频 / 下载）：图标 ghost 胶囊，与实心主 CTA 形成层级差；
   卡面空间有限（168×208，内容区约 128px），三键必须单行容纳 → 图标化 + 紧凑尺寸，
   完整语义由 title/aria-label 与详情弹窗按钮承载 */
.lnk--ghost {
  display: inline-grid;
  place-items: center;
  min-width: 1.5rem;
  height: 1.5rem;
  padding: 0 0.3rem;
  font-size: 0.7rem;
  font-weight: 700;
  line-height: 1;
  border-radius: 999px;
  text-decoration: none;
  color: var(--color-accent-strong, var(--color-accent));
  background: color-mix(in srgb, var(--color-accent) 10%, transparent);
  border: 1px solid color-mix(in srgb, var(--color-accent) 32%, transparent);
  transition: background 0.2s ease, border-color 0.2s ease, color 0.2s ease,
    transform 0.15s ease;
}
.lnk--ghost:hover {
  color: var(--color-accent-strong, var(--color-accent));
  background: color-mix(in srgb, var(--color-accent) 20%, transparent);
  border-color: color-mix(in srgb, var(--color-accent) 55%, transparent);
  transform: translateY(-1px);
}

/* ---------- 旋转箭头：始终可见、命中区更大、悬停/焦点状态清晰 ---------- */
.ring-nav {
  flex: none;
  width: 46px;
  height: 46px;
  border-radius: 50%;
  font-size: 1.6rem;
  line-height: 1;
  cursor: pointer;
  display: grid;
  place-items: center;
  border: 1px solid color-mix(in srgb, var(--color-border) 82%, transparent);
  background: color-mix(in srgb, var(--color-bg-surface) 70%, var(--color-bg-elevated));
  color: var(--color-text-on-surface);
  box-shadow: 0 8px 22px -10px rgba(0, 0, 0, 0.6);
  transition: border-color 0.2s ease, transform 0.2s ease, box-shadow 0.2s ease,
    background-color 0.2s ease, color 0.2s ease;
  z-index: 5;
}
.ring-nav:hover,
.ring-nav:focus-visible {
  border-color: var(--color-accent);
  background: color-mix(in srgb, var(--color-accent) 22%, var(--color-bg-surface));
  color: var(--color-accent-strong);
  transform: scale(1.1);
  box-shadow: 0 10px 26px -8px color-mix(in srgb, var(--color-accent) 52%, transparent);
}
.ring-nav:active {
  transform: scale(0.95);
}
.ring-nav:focus-visible {
  outline: 2px solid var(--color-focus);
  outline-offset: 2px;
}

/* ---------- 分页 ---------- */
.pager {
  margin-top: 1.6rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.6rem;
}
.pg-info {
  font-size: 0.78rem;
  color: var(--color-text-muted);
}
.pg-btns {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}
.pg-btn {
  width: 34px;
  height: 34px;
  border-radius: 9px;
  border: 1px solid var(--color-border);
  background: var(--color-bg-surface);
  color: var(--color-text-on-surface);
  cursor: pointer;
  font-size: 1.1rem;
  transition: border-color 0.2s ease, transform 0.2s ease;
}
.pg-btn:hover:not(:disabled) {
  border-color: var(--color-accent);
  transform: translateY(-1px);
}
.pg-btn:disabled {
  opacity: 0.35;
  cursor: not-allowed;
}
.pg-dot {
  min-width: 34px;
  height: 34px;
  padding: 0 0.5rem;
  border-radius: 9px;
  border: 1px solid var(--color-border);
  background: var(--color-bg-surface);
  color: var(--color-text-muted);
  cursor: pointer;
  font-weight: 600;
  font-size: 0.85rem;
  transition: background 0.2s ease, color 0.2s ease, border-color 0.2s ease;
}
.pg-dot:hover {
  border-color: var(--color-accent);
  color: var(--color-link);
}
.pg-dot.active {
  background: var(--color-accent);
  color: var(--color-text-on-accent);
  border-color: transparent;
}

/* ---------- 详情弹窗 ---------- */
.dt-mask {
  position: fixed;
  inset: 0;
  z-index: 55;
  display: grid;
  place-items: center;
  padding: 1.2rem;
  background: rgba(6, 11, 22, 0.62);
  backdrop-filter: blur(4px);
  animation: cmFade 0.18s ease both;
}
.dt-panel {
  position: relative;
  width: min(480px, 100%);
  padding: 1.6rem 1.7rem;
  border-radius: 16px;
  background: var(--color-bg-surface);
  color: var(--color-text-on-surface);
  border: 1px solid var(--color-border);
  box-shadow: 0 26px 70px -22px rgba(0, 0, 0, 0.7);
  animation: cmPop 0.22s cubic-bezier(0.16, 1, 0.3, 1) both;
}
.dt-close {
  position: absolute;
  top: 0.7rem;
  right: 0.7rem;
  width: 30px;
  height: 30px;
  border-radius: 8px;
  border: 1px solid var(--color-border);
  background: var(--color-bg-elevated);
  color: var(--color-text-on-surface);
  cursor: pointer;
  font-size: 0.9rem;
}
.dt-close:hover {
  color: var(--color-error, #ff8e8e);
}
.dt-cat {
  font-size: 0.72rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-accent-strong, var(--color-accent));
}
.dt-title {
  margin: 0.3rem 0 0.8rem;
  font-size: 1.4rem;
}
.dt-summary {
  margin: 0 0 1rem;
  line-height: 1.65;
  color: var(--color-text-muted);
}
.dt-tech {
  margin-bottom: 1.2rem;
}
.dt-actions {
  display: flex;
  gap: 0.8rem;
  flex-wrap: wrap;
}
.dt-link {
  font-size: 0.85rem;
  font-weight: 600;
  padding: 0.45rem 0.9rem;
  border-radius: 9px;
  border: 1px solid var(--color-border);
  background: var(--color-bg-elevated);
  color: var(--color-text-on-surface);
  cursor: pointer;
  text-decoration: none;
  transition: border-color 0.2s ease, color 0.2s ease;
}
.dt-link:hover {
  border-color: var(--color-accent);
  color: var(--color-link);
}
.dt-link--primary {
  background: var(--color-accent);
  color: var(--color-text-on-accent);
  border-color: transparent;
}

@keyframes cmFade {
  from { opacity: 0; }
  to { opacity: 1; }
}
@keyframes cmPop {
  from { opacity: 0; transform: translateY(14px) scale(0.98); }
  to { opacity: 1; transform: none; }
}
@media (prefers-reduced-motion: reduce) {
  .orbit,
  .dt-mask,
  .dt-panel,
  .card__vol {
    animation: none;
    transition: none;
  }
  /* 降低动效偏好下，不再翻起检视，仅保留平面可读性 */
  .viewport:not(.dragging) .card:hover .card__vol {
    transform: none;
  }
}
</style>
