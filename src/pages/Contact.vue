<script setup>
import { useContent } from '@/composables/useContent'

const { profile } = useContent()
const c = profile.contact

const items = [
  {
    key: 'github',
    label: 'GitHub',
    value: '@wu-ping0817',
    href: c.github,
    desc: '代码与作品仓库，欢迎来翻翻',
  },
  {
    key: 'email',
    label: '邮箱',
    value: c.email || '（还在路上）',
    href: c.email ? `mailto:${c.email}` : null,
    desc: '邮件联系，慢一点也没关系',
  },
  {
    key: 'wechat',
    label: '微信',
    value: c.wechat || '（待补充）',
    href: null,
    desc: '即时沟通，适合闲聊',
  },
]
</script>

<template>
  <section class="screen contact">
    <header class="head">
      <h1 class="page-title">最远的距离</h1>
      <p class="page-desc">
        是你明明想找我，却在页面里迷了路。别慌，下面这几条路都能通到我这儿。
      </p>
    </header>

    <div class="cards">
      <article
        v-for="(it, i) in items"
        :key="it.key"
        class="card"
        v-tilt="{ max: 8, scale: 1.03 }"
      >
        <h3 class="card-label">{{ it.label }}</h3>
        <p class="card-value">
          <a v-if="it.href" :href="it.href" target="_blank" rel="noopener noreferrer">
            {{ it.value }} ↗
          </a>
          <span v-else>{{ it.value }}</span>
        </p>
        <p class="card-desc">{{ it.desc }}</p>
      </article>
    </div>

    <p class="note">{{ c.note }}</p>
  </section>
</template>

<style scoped>
.contact {
  text-align: left;
}
.head {
  margin-bottom: 2rem;
}
.page-title {
  margin: 0 0 0.5rem;
  font-size: 2rem;
}
.page-desc {
  margin: 0;
  color: var(--color-text-muted);
  max-width: 48ch;
}

.cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 1.2rem;
}
.card {
  padding: 1.4rem 1.5rem;
  border-radius: 16px;
  background: var(--color-bg-surface);
  color: var(--color-text-on-surface);
  border: 1px solid var(--color-border);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}
.card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 26px rgba(0, 0, 0, 0.22);
}
.card-label {
  margin: 0 0 0.5rem;
  font-size: 0.85rem;
  letter-spacing: 0.1em;
  color: var(--color-text-muted);
}
.card-value {
  margin: 0 0 0.4rem;
  font-size: 1.25rem;
  font-weight: 600;
}
.card-value a {
  color: var(--color-accent-strong, var(--color-accent));
}
.card-desc {
  margin: 0;
  font-size: 0.85rem;
  opacity: 0.82;
}
.note {
  margin-top: 1.8rem;
  font-size: 0.85rem;
  color: var(--color-text-muted);
}
</style>
