<script setup>
import { ref } from 'vue'
import ImageSlot from '@/components/ImageSlot.vue'

// 问他一个问题：随机回一句神秘又带点俏皮的话
const answers = [
  '……（他假装没听见）',
  '这个问题，他拒绝回答。',
  '答案嘛——你猜咯。',
  '（已读不回）',
  '他只回了个表情包。',
  '“别问，问就是随缘。”',
  '“这件事，得等一个不下雨的下午。”',
]
const asked = ref(false)
const answer = ref('')
function askHim() {
  asked.value = true
  answer.value = answers[Math.floor(Math.random() * answers.length)]
}
</script>

<template>
  <section class="screen home">
    <div class="home-inner">
      <span class="eyebrow">（门没锁，随便进）</span>

      <div class="avatar">
        <ImageSlot
          src="img/avatar.webp"
          alt="头像"
          :title="'温暖'"
          variant="photo"
          ratio="1 / 1"
          round
        />
      </div>

      <h1 class="name gradient-text">温暖</h1>
      <p class="role">一个不想被贴标签的普通人类</p>
      <p class="intro">
        没啥拿得出手的 title，就爱把庸常的一天，过出点不按套路来的小乐子。
      </p>

      <div class="ask">
        <button class="ask-btn" type="button" @click="askHim">
          戳我一下，看我蹦出啥
        </button>
        <p class="ask-answer" :class="{ shown: asked }" aria-live="polite">
          {{ answer }}
        </p>
      </div>

      <p class="hint">下面那个「下一步」，慢慢翻就完事了 →</p>
    </div>

    <!-- 背景里飘着的小问号，纯装饰 -->
    <span class="float-q q1" aria-hidden="true">？</span>
    <span class="float-q q2" aria-hidden="true">·</span>
    <span class="float-q q3" aria-hidden="true">？</span>
  </section>
</template>

<style scoped>
.home {
  position: relative;
  text-align: center;
  overflow: hidden;
}
.home-inner {
  position: relative;
  z-index: 2;
  max-width: 560px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.85rem;
}

.eyebrow {
  font-size: 0.9rem;
  letter-spacing: 0.18em;
  color: var(--color-link);
  opacity: 0.9;
}
.avatar {
  width: 116px;
  height: 116px;
  border-radius: 50%;
  overflow: hidden;
  border: 2px solid color-mix(in srgb, var(--color-accent) 50%, transparent);
  box-shadow: 0 10px 30px -12px rgba(0, 0, 0, 0.5);
}
.name {
  margin: 0;
  font-size: clamp(2.6rem, 8vw, 4rem);
  line-height: 1.05;
  font-weight: 800;
  letter-spacing: 0.02em;
}
.gradient-text {
  background: linear-gradient(
    100deg,
    var(--color-text-base) 0%,
    var(--color-link) 50%,
    var(--color-text-base) 100%
  );
  background-size: 220% 100%;
  -webkit-background-clip: text;
  background-clip: text;
  animation: shade 7s ease-in-out infinite;
  color: var(--color-text-base);
}
@supports ((-webkit-background-clip: text) or (background-clip: text)) {
  .gradient-text {
    color: transparent;
  }
}
@keyframes shade {
  0% {
    background-position: 0% 50%;
  }
  50% {
    background-position: 100% 50%;
  }
  100% {
    background-position: 0% 50%;
  }
}
.role {
  margin: 0;
  font-size: clamp(1rem, 2.4vw, 1.25rem);
  font-weight: 500;
  color: var(--color-text-base);
  opacity: 0.92;
}
.intro {
  margin: 0.2rem 0 0;
  max-width: 440px;
  font-size: 0.98rem;
  line-height: 1.8;
  color: var(--color-text-muted);
}

.ask {
  margin-top: 0.4rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.6rem;
}
.ask-btn {
  border: 1px solid var(--color-border);
  background: var(--color-bg-surface);
  color: var(--color-text-on-surface);
  border-radius: 999px;
  padding: 0.6rem 1.3rem;
  font-weight: 600;
  font-size: 0.95rem;
  cursor: pointer;
  transition: background 0.2s ease, transform 0.2s ease, border-color 0.2s ease;
}
.ask-btn:hover {
  border-color: var(--color-accent);
  transform: translateY(-2px);
}
.ask-answer {
  margin: 0;
  min-height: 1.6em;
  font-size: 1.1rem;
  color: var(--color-text-base);
  opacity: 0;
  transform: translateY(8px);
  transition: opacity 0.45s ease, transform 0.45s ease;
}
.ask-answer.shown {
  opacity: 1;
  transform: none;
}

.hint {
  margin: 0.6rem 0 0;
  font-size: 0.85rem;
  color: var(--color-text-muted);
  opacity: 0.8;
}

/* 背景装饰小问号 */
.float-q {
  position: absolute;
  z-index: 1;
  color: var(--color-accent);
  opacity: 0.18;
  font-weight: 800;
  pointer-events: none;
  animation: drift 9s ease-in-out infinite;
}
.q1 {
  top: 16%;
  left: 14%;
  font-size: 3rem;
}
.q2 {
  top: 26%;
  right: 16%;
  font-size: 2rem;
  animation-delay: 1.4s;
}
.q3 {
  bottom: 22%;
  left: 22%;
  font-size: 2.4rem;
  animation-delay: 2.6s;
}
@keyframes drift {
  0%,
  100% {
    transform: translateY(0) rotate(0deg);
    opacity: 0.12;
  }
  50% {
    transform: translateY(-18px) rotate(8deg);
    opacity: 0.26;
  }
}

@media (prefers-reduced-motion: reduce) {
  .gradient-text,
  .float-q {
    animation: none !important;
  }
  .ask-answer {
    opacity: 1 !important;
    transform: none !important;
  }
  .gradient-text {
    color: var(--color-text-base) !important;
    background: none !important;
    -webkit-background-clip: border-box !important;
    background-clip: border-box !important;
  }
}
</style>
