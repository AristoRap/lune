<script setup>
import { ref, onMounted, onBeforeUnmount } from "vue";
import { DeepLink } from "../lune.js";

const toasts = ref([]);
let nextId = 0;

function push(message, duration = 4000) {
  const id = nextId++;
  toasts.value.push({ id, message });
  setTimeout(() => dismiss(id), duration);
}

function dismiss(id) {
  toasts.value = toasts.value.filter((t) => t.id !== id);
}

function handleDeepLink(url) {
  push(`Deep link received: ${url}`);
}

onMounted(() => DeepLink.on(handleDeepLink));
onBeforeUnmount(() => DeepLink.off());
</script>

<template>
  <Teleport to="body">
    <div class="toast-stack">
      <TransitionGroup name="toast">
        <div
          v-for="t in toasts"
          :key="t.id"
          class="toast"
          @click="dismiss(t.id)"
        >
          <span class="toast-icon">🔗</span>
          <span class="toast-msg">{{ t.message }}</span>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<style scoped>
.toast-stack {
  position: fixed;
  bottom: 2.5rem;
  right: 1.5rem;
  display: flex;
  flex-direction: column-reverse;
  gap: 0.55rem;
  z-index: 9999;
  pointer-events: none;
}

.toast {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.65rem 1rem;
  background: var(--surface-hi, #1e1e2e);
  border: 1px solid rgba(167, 139, 250, 0.35);
  border-radius: var(--radius, 8px);
  box-shadow: 0 4px 18px rgba(0, 0, 0, 0.45);
  font-size: 0.85em;
  color: var(--text, #e2e8f0);
  cursor: pointer;
  pointer-events: auto;
  max-width: 380px;
  word-break: break-all;
}

.toast-icon {
  font-size: 1em;
  flex-shrink: 0;
}

.toast-msg {
  font-family: var(--font-mono);
  color: var(--moon-2, #c4b5fd);
  line-height: 1.4;
}

.toast-enter-active,
.toast-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}

.toast-enter-from {
  opacity: 0;
  transform: translateY(8px);
}

.toast-leave-to {
  opacity: 0;
  transform: translateY(8px);
}
</style>
