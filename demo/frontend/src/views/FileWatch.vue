<script setup>
import { ref, onUnmounted } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { lune } from "../lune.js";
const { FileWatch } = lune;

const pathInput = ref("");
const watched = ref([]); // string[]
const events = ref([]); // { path, kind, ts }
let nextId = 1;

const handler = (ev) => {
  events.value.unshift({ id: nextId++, path: ev.path, kind: ev.kind, ts: new Date().toLocaleTimeString() });
  if (events.value.length > 50) events.value.pop();
};

FileWatch.on(handler);
onUnmounted(() => FileWatch.off(handler));

function addWatch() {
  const p = pathInput.value.trim();
  if (!p || watched.value.includes(p)) return;
  FileWatch.watch(p);
  watched.value.push(p);
  pathInput.value = "";
}

function removeWatch(path) {
  FileWatch.unwatch(path);
  watched.value = watched.value.filter((p) => p !== path);
}

function clearLog() {
  events.value = [];
}

const KIND_CLASS = {
  modified: "kind--modified",
  created:  "kind--created",
  deleted:  "kind--deleted",
  renamed:  "kind--renamed",
};
</script>

<template>
  <SectionHead eyebrow="Filesystem" title="File Watch">
    <template #desc>
      Watch files and directories for changes. Backed by <strong>kqueue</strong> on macOS
      and <strong>inotify</strong> on Linux — no polling, no extra dependencies.
    </template>
  </SectionHead>

  <div class="card-grid">
    <div class="card">
      <span class="card-label">Watch a path</span>
      <div class="row">
        <input
          v-model="pathInput"
          type="text"
          placeholder="/tmp/myfile.txt"
          @keydown.enter="addWatch"
        />
        <button class="primary" @click="addWatch">Watch</button>
      </div>
      <div class="watched-list">
        <div v-if="!watched.length" class="log-empty">No paths watched yet…</div>
        <div v-for="p in watched" :key="p" class="watched-entry">
          <span class="live-dot"></span>
          <span class="watched-path">{{ p }}</span>
          <button class="btn-unwatch" @click="removeWatch(p)">✕</button>
        </div>
      </div>
    </div>

    <div class="card">
      <div class="log-header">
        <span class="card-label">Events</span>
        <button v-if="events.length" class="btn-clear" @click="clearLog">Clear</button>
      </div>
      <div class="log">
        <div v-if="!events.length" class="log-empty">
          Watch a path then modify or delete the file…
        </div>
        <div v-for="ev in events" :key="ev.id" class="log-entry">
          <span class="ev-ts">{{ ev.ts }}</span>
          <span class="ev-kind" :class="KIND_CLASS[ev.kind] || ''">{{ ev.kind }}</span>
          <span class="ev-path">{{ ev.path }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.watched-list {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  margin-top: 0.6rem;
}

.watched-entry {
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

.watched-path {
  font-family: var(--font-mono);
  color: var(--text);
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.btn-unwatch {
  background: none;
  border: none;
  color: var(--muted);
  cursor: pointer;
  font-size: 0.8em;
  padding: 0.1rem 0.3rem;
  border-radius: 4px;
  line-height: 1;
}
.btn-unwatch:hover { color: var(--err, #f87171); background: rgba(248, 113, 113, 0.08); }

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
  gap: 0.3rem;
  max-height: 260px;
  overflow-y: auto;
}

.log-entry {
  display: grid;
  grid-template-columns: auto auto 1fr;
  gap: 0.55rem;
  align-items: baseline;
  font-size: 0.82em;
  font-family: var(--font-mono);
}

.ev-ts {
  color: var(--muted);
  white-space: nowrap;
}

.ev-kind {
  font-size: 0.75em;
  font-weight: 700;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  padding: 0.1em 0.45em;
  border-radius: 4px;
  white-space: nowrap;
}

.kind--modified { background: rgba(167, 139, 250, 0.15); color: var(--moon-2); }
.kind--created  { background: rgba(52, 211, 153, 0.12);  color: var(--ok); }
.kind--deleted  { background: rgba(248, 113, 113, 0.12); color: var(--err, #f87171); }
.kind--renamed  { background: rgba(251, 191, 36, 0.12);  color: #fcd34d; }

.ev-path {
  color: var(--text-mid, var(--text));
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
