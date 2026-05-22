<script setup>
import { ref, onMounted, onBeforeUnmount } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { Windows, Events } from "../lune.js";

const openWindows = ref([]);
const log = ref([]);
const currentUrl = window.location.href;
const sqliteUrl = window.location.href.replace(/#.*$/, "") + "#/sqlite";

function addLog(msg) {
  log.value.unshift(`${new Date().toLocaleTimeString()} ${msg}`);
  if (log.value.length > 20) log.value.pop();
}

async function openWindow(opts) {
  try {
    const id = await Windows.open(opts);
    openWindows.value.push({ id, title: opts.title || "Window" });
    addLog(`opened "${opts.title || "Window"}" → ${id}`);
  } catch (err) {
    addLog(`error: ${err.message || String(err)}`);
  }
}

async function closeWindow(id) {
  try {
    await Windows.close(id);
    openWindows.value = openWindows.value.filter((w) => w.id !== id);
    addLog(`closed ${id}`);
  } catch (err) {
    addLog(`error closing ${id}: ${err.message || String(err)}`);
  }
}

async function listWindows() {
  try {
    const ids = await Windows.list();
    const known = Object.fromEntries(openWindows.value.map((w) => [w.id, w.title]));
    openWindows.value = ids.map((id) => ({ id, title: known[id] || "Window" }));
    addLog(`list → [${ids.join(", ") || "empty"}]`);
  } catch (err) {
    addLog(`error: ${err.message || String(err)}`);
  }
}

const onWindowClosed = (data) => {
  const id = data?.id;
  if (id) {
    openWindows.value = openWindows.value.filter((w) => w.id !== id);
    addLog(`closed ${id} (OS)`);
  }
};

onMounted(() => Events.on("window_closed", onWindowClosed));
onBeforeUnmount(() => Events.off("window_closed", onWindowClosed));
</script>

<template>
  <SectionHead eyebrow="Native" title="Windows">
    <template #desc>
      Open additional native windows pointing to any URL. Each window shares
      the same plugin bindings as the main window.
    </template>
  </SectionHead>

  <div class="card-grid">
    <!-- Spawn controls -->
    <div class="card">
      <span class="card-label">Open a window</span>
      <div class="btn-col">
        <button class="primary"
          @click="openWindow({ title: 'Windows — copy', url: currentUrl, width: 800, height: 600 })">
          Open this view in a new window
        </button>
        <button class="primary" @click="openWindow({ title: 'SQLite', url: sqliteUrl, width: 800, height: 600 })">
          Open SQLite view in a new window
        </button>
      </div>
      <p class="hint">
        Any route can be targeted — pass any <code>#/route</code> hash to land
        on a specific view.
      </p>
    </div>

    <!-- Open windows list -->
    <div class="card">
      <span class="card-label">Open windows</span>
      <button class="ghost" @click="listWindows">Refresh list</button>
      <div v-if="!openWindows.length" class="empty">No extra windows open.</div>
      <div v-else class="window-list">
        <div v-for="w in openWindows" :key="w.id" class="window-row">
          <span class="win-title">{{ w.title }}</span>
          <span class="win-id">{{ w.id }}</span>
          <button class="danger small" @click="closeWindow(w.id)">Close</button>
        </div>
      </div>
    </div>

    <!-- Log -->
    <div class="card full-width">
      <span class="card-label">Log</span>
      <div v-if="!log.length" class="empty">No events yet.</div>
      <div v-else class="log-list">
        <div v-for="(entry, i) in log" :key="i" class="log-entry">{{ entry }}</div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.btn-col {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.window-list {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  margin-top: 0.5rem;
}

.window-row {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  font-size: 0.82em;
  padding: 0.35rem 0.5rem;
  background: rgba(0, 0, 0, 0.15);
  border: 1px solid var(--border);
  border-radius: 4px;
}

.win-title {
  font-weight: 600;
  flex-shrink: 0;
}

.win-id {
  font-family: var(--font-mono);
  color: var(--muted);
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ghost {
  font-size: 0.8em;
  padding: 0.3rem 0.7rem;
  background: transparent;
  border: 1px solid var(--border);
  border-radius: 4px;
  color: inherit;
  cursor: pointer;
  margin-bottom: 0.5rem;
}

.ghost:hover {
  background: rgba(255, 255, 255, 0.06);
}

button.small {
  font-size: 0.75em;
  padding: 0.2rem 0.55rem;
}

.empty {
  font-size: 0.82em;
  color: var(--muted);
  font-style: italic;
  margin-top: 0.4rem;
}

.log-list {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  max-height: 180px;
  overflow-y: auto;
}

.log-entry {
  font-family: var(--font-mono);
  font-size: 0.8em;
  color: var(--muted);
  white-space: pre;
}

.full-width {
  grid-column: 1 / -1;
}
</style>
