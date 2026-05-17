<script setup>
defineProps({
  message: { type: String, default: "Ready" },
  clock: { type: String, default: "" },
  clockPaused: { type: Boolean, default: false },
});
</script>

<template>
  <footer id="statusbar">
    <div class="left">
      <span class="pulse"></span>
      <span class="msg">{{ message }}</span>
    </div>
    <div class="right">
      <span class="chip"><kbd>⌘</kbd><kbd>R</kbd> reload</span>
      <span class="chip"><kbd>⌘</kbd><kbd>P</kbd> pause clock</span>
      <span class="chip"><kbd>⌘</kbd><kbd>Q</kbd> quit</span>
      <span
        v-if="clock"
        class="clock-chip"
        :class="clockPaused ? 'clock-chip--paused' : 'clock-chip--live'"
      >
        <span class="clock-dot"></span>
        {{ clock }}
      </span>
    </div>
  </footer>
</template>

<style scoped>
#statusbar {
  height: var(--statusbar-h);
  background: rgba(7, 8, 15, 0.72);
  border-top: 1px solid var(--border);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 0.9rem;
  font-size: 0.75em;
  color: var(--text-mid);
  position: relative;
  z-index: 2;
  flex-shrink: 0;
}

.left,
.right {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.pulse {
  width: 7px;
  height: 7px;
  border-radius: 99px;
  background: var(--ok);
  box-shadow: 0 0 10px rgba(52, 211, 153, 0.7);
  animation: pulse 2.4s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50%      { opacity: 0.55; transform: scale(0.8); }
}

.chip {
  display: inline-flex;
  align-items: center;
  gap: 0.3em;
  color: var(--muted);
  letter-spacing: 0.02em;
}
.chip kbd {
  font-family: var(--font-mono);
  font-size: 0.85em;
  padding: 0 0.3em;
  border-radius: 3px;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid var(--border);
  color: var(--text-mid);
}

.clock-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.35em;
  font-family: var(--font-mono);
  font-variant-numeric: tabular-nums;
  transition:
    color 220ms ease,
    opacity 220ms ease,
    text-shadow 220ms ease;
}

.clock-dot {
  width: 6px;
  height: 6px;
  border-radius: 99px;
  transition: background 220ms ease, box-shadow 220ms ease;
}

.clock-chip--live {
  color: #84ff52;
  text-shadow: 0 0 10px rgba(132, 255, 82, 0.45);
}
.clock-chip--live .clock-dot {
  background: #84ff52;
  box-shadow: 0 0 8px rgba(132, 255, 82, 0.7);
}

.clock-chip--paused {
  color: var(--muted);
  opacity: 0.5;
}
.clock-chip--paused .clock-dot {
  background: var(--muted);
}
</style>
