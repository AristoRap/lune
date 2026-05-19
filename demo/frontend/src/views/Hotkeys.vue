<script setup>
import { ref, onUnmounted } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { Hotkeys, Events } from "../lune.js";

const keyInput = ref("");
const registered = ref([]);
const log = ref([]);
let nextId = 1;

const handler = (data) => {
  log.value.unshift({ id: nextId++, key: data.key, ts: new Date().toLocaleTimeString() });
  if (log.value.length > 50) log.value.pop();
};

Events.on("hotkey", handler);
onUnmounted(() => Events.off("hotkey", handler));

async function register() {
  const k = keyInput.value.trim();
  if (!k || registered.value.includes(k)) return;
  await Hotkeys.register(k);
  registered.value.push(k);
  keyInput.value = "";
}

async function unregister(key) {
  await Hotkeys.unregister(key);
  registered.value = registered.value.filter((k) => k !== key);
}

function clearLog() {
  log.value = [];
}
</script>

<template>
  <SectionHead eyebrow="Input" title="Hotkeys">
    <template #desc>
      System-wide keyboard shortcuts that fire even when the window is not focused.
      Registered via <strong>Carbon RegisterEventHotKey</strong> on macOS — no Accessibility
      permission required.
    </template>
  </SectionHead>

  <div class="card-grid">
    <div class="card">
      <span class="card-label">Register a shortcut</span>
      <div class="row">
        <input
          v-model="keyInput"
          type="text"
          placeholder="Ctrl+Shift+K"
          @keydown.enter="register"
        />
        <button class="primary" @click="register">Register</button>
      </div>
      <div class="hint">
        Format: <code>Ctrl+K</code>, <code>Cmd+Shift+P</code>, <code>Alt+F4</code>
      </div>
      <div class="registered-list">
        <div v-if="!registered.length" class="log-empty">No shortcuts registered yet…</div>
        <div v-for="k in registered" :key="k" class="registered-entry">
          <span class="live-dot"></span>
          <span class="key-badge">{{ k }}</span>
          <button class="btn-remove" @click="unregister(k)">✕</button>
        </div>
      </div>
    </div>

    <div class="card">
      <div class="log-header">
        <span class="card-label">Triggered</span>
        <button v-if="log.length" class="btn-clear" @click="clearLog">Clear</button>
      </div>
      <div class="log">
        <div v-if="!log.length" class="log-empty">
          Register a shortcut then press it globally…
        </div>
        <div v-for="entry in log" :key="entry.id" class="log-entry">
          <span class="ev-ts">{{ entry.ts }}</span>
          <span class="key-badge">{{ entry.key }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.hint {
  font-size: 0.78em;
  color: var(--muted);
  margin-top: 0.5rem;
}
.hint code {
  font-family: var(--font-mono);
  background: rgba(255,255,255,0.06);
  padding: 0.1em 0.35em;
  border-radius: 3px;
}

.registered-list {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  margin-top: 0.6rem;
}

.registered-entry {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  font-size: 0.85em;
}

.live-dot {
  width: 6px;
  height: 6px;
  border-radius: 99px;
  background: var(--ok);
  box-shadow: 0 0 6px rgba(52, 211, 153, 0.6);
  flex-shrink: 0;
}

.key-badge {
  font-family: var(--font-mono);
  font-size: 0.85em;
  background: rgba(167, 139, 250, 0.12);
  color: var(--moon-2);
  padding: 0.15em 0.55em;
  border-radius: 4px;
  white-space: nowrap;
}

.btn-remove {
  background: none;
  border: none;
  color: var(--muted);
  cursor: pointer;
  font-size: 0.8em;
  padding: 0.1rem 0.3rem;
  border-radius: 4px;
  line-height: 1;
  margin-left: auto;
}
.btn-remove:hover { color: var(--err, #f87171); background: rgba(248, 113, 113, 0.08); }

.log-header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: 0.4rem;
}

.btn-clear {
  font-size: 0.75em;
  color: var(--muted);
  background: none;
  border: none;
  cursor: pointer;
  padding: 0;
}
.btn-clear:hover { color: var(--text); }

.log {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  max-height: 260px;
  overflow-y: auto;
}

.log-entry {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  font-size: 0.83em;
  font-family: var(--font-mono);
}

.ev-ts {
  color: var(--muted);
  white-space: nowrap;
}
</style>
