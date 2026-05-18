<script setup>
import { nextTick, ref, useTemplateRef } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { api, Dialogs, Events } from "../lune.js";
import { useLuneEvent } from "../composables/useLuneEvent.js";

const clock = ref("—");
const paused = ref(false);
const pingValue = ref("hello");
const rounds = ref([]); // { id, ping, pong, sentAt, ms }
const progress = ref(null); // { done, total, name }
const dropLog = ref([]);

let nextId = 1;
const roundsEl = useTemplateRef("roundsEl");

function scrollRoundsToBottom() {
  nextTick(() => {
    const el = roundsEl.value;
    if (el) el.scrollTop = el.scrollHeight;
  });
}

useLuneEvent("tick", (ts) => {
  clock.value = new Date(ts).toLocaleTimeString();
});
useLuneEvent("clockPaused", (v) => (paused.value = v));
useLuneEvent("pong", (data) => {
  const pending = rounds.value.find((r) => r.pong === undefined);
  if (pending) {
    pending.pong = data;
    pending.ms = performance.now() - pending.sentAt;
  } else {
    rounds.value.push({
      id: nextId++,
      ping: undefined,
      pong: data,
      sentAt: performance.now(),
      ms: 0,
    });
  }
  scrollRoundsToBottom();
});
useLuneEvent("fileProgress", ({ done, total, name }) => {
  progress.value = { done, total, name, percent: (done / total) * 100 };
});
useLuneEvent("file_drop", ({ x, y, paths }) => {
  const hit = document.elementFromPoint(x, y);
  const zone = hit?.closest("#drop-b") ? "B" : "A";
  paths.forEach((p) => dropLog.value.unshift({ zone, path: p }));
});

async function sendPing() {
  rounds.value.push({
    id: nextId++,
    ping: pingValue.value,
    pong: undefined,
    sentAt: performance.now(),
    ms: 0,
  });
  scrollRoundsToBottom();
  await Events.emit("ping", pingValue.value);
}

function fmtVal(v) {
  if (v === undefined || v === null) return "—";
  if (typeof v === "string") return v;
  return JSON.stringify(v);
}

async function pickAndProcess() {
  const paths = await Dialogs.openFiles("Select files to process");
  if (!paths.length) return;
  progress.value = null;
  await api.Demo.processFiles(paths);
}
</script>

<template>
  <SectionHead eyebrow="Bidirectional" title="Events">
    <template #desc>
      A small bus connects Crystal and JS. Crystal calls
      <code>app.emit</code>; JavaScript calls <code>emit()</code>. Either
      side can subscribe with <code>on()</code>.
    </template>
  </SectionHead>

  <div class="card-grid">
    <div class="card">
      <span class="card-label">Live clock — Crystal → JS</span>
      <div class="clock-row">
        <div class="clock" :class="paused ? 'clock--paused' : 'clock--live'">
          {{ clock }}
        </div>
        <span v-if="paused" class="badge badge--stopped">Stopped</span>
        <span v-else class="badge badge--live">
          <span class="live-dot"></span> live
        </span>
      </div>
      <p class="hint">
        Crystal emits <code>"tick"</code> every second.
        Use <code>File → Pause Clock</code> (⌘P) to toggle.
      </p>
    </div>

    <div class="card">
      <span class="card-label">Ping / Pong — JS → Crystal → JS</span>
      <div class="row">
        <input v-model="pingValue" type="text" @keydown.enter="sendPing" />
        <button class="primary" @click="sendPing">Ping</button>
      </div>
      <div ref="roundsEl" class="rounds">
        <div v-if="!rounds.length" class="log-empty">
          Send a ping to see it return as pong…
        </div>
        <div v-for="r in rounds" :key="r.id" class="round">
          <span class="round-index">#{{ r.id }}</span>
          <span class="bubble bubble-out">
            <span class="bubble-tag">PING</span>
            <span class="bubble-text">{{ fmtVal(r.ping) }}</span>
          </span>
          <span class="round-arrow">
            <span class="round-line" :class="{ pending: r.pong === undefined }"></span>
          </span>
          <span class="bubble bubble-in" :class="{ 'bubble-pending': r.pong === undefined }">
            <span class="bubble-tag">PONG</span>
            <span class="bubble-text">
              <template v-if="r.pong !== undefined">{{ fmtVal(r.pong) }}</template>
              <template v-else>…</template>
            </span>
          </span>
          <span v-if="r.pong !== undefined" class="round-ms">
            {{ r.ms.toFixed(1) }} ms
          </span>
        </div>
      </div>
    </div>

    <div class="card">
      <span class="card-label">Async progress — binding + events</span>
      <button @click="pickAndProcess">Pick files &amp; process</button>
      <div v-if="progress" class="progress-wrap">
        <div class="progress-track">
          <div class="progress-bar" :style="{ width: `${progress.percent}%` }"></div>
        </div>
        <p class="hint">{{ progress.done }}/{{ progress.total }} — {{ progress.name }}</p>
      </div>
    </div>

    <div class="card">
      <span class="card-label">File drop — scoped zones</span>
      <div class="drop-zone-grid">
        <div class="drop-target" style="--lune-drop-target: drop" id="drop-a">
          <span class="drop-target__title">Zone A</span>
          <span class="drop-target__hint">Drop files here</span>
        </div>
        <div class="drop-target drop-target--alt" style="--lune-drop-target: drop" id="drop-b">
          <span class="drop-target__title">Zone B</span>
          <span class="drop-target__hint">Drop files here</span>
        </div>
      </div>
      <div class="log">
        <div v-if="!dropLog.length" class="log-empty">Dropped files appear here…</div>
        <div v-for="(d, i) in dropLog" :key="i" class="log-entry">
          [Zone {{ d.zone }}] {{ d.path }}
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.live-dot {
  width: 6px;
  height: 6px;
  border-radius: 99px;
  background: var(--ok);
  box-shadow: 0 0 8px rgba(52, 211, 153, 0.7);
  display: inline-block;
}

.progress-wrap {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

/* ping/pong rounds */
.rounds {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  max-height: 180px;
  overflow-y: auto;
}

.round {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) 28px minmax(0, 1fr) auto;
  align-items: center;
  gap: 0.5rem;
}

.round-index {
  font-family: var(--font-mono);
  font-size: 0.72em;
  font-weight: 600;
  color: var(--muted);
  letter-spacing: 0.04em;
  min-width: 2.4em;
  text-align: right;
}

.bubble {
  display: inline-flex;
  align-items: center;
  gap: 0.5em;
  padding: 0.45em 0.7em;
  border-radius: 8px;
  font-size: 0.85em;
  border: 1px solid var(--border);
  min-width: 0;
}

.bubble-tag {
  font-family: var(--font-mono);
  font-size: 0.62em;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  font-weight: 700;
  opacity: 0.75;
}

.bubble-text {
  font-family: var(--font-mono);
  font-size: 0.95em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.bubble-out {
  background: linear-gradient(135deg,
      rgba(167, 139, 250, 0.18),
      rgba(124, 108, 255, 0.1));
  border-color: rgba(167, 139, 250, 0.32);
  color: var(--moon-2);
  justify-content: flex-end;
}

.bubble-in {
  background: rgba(52, 211, 153, 0.08);
  border-color: rgba(52, 211, 153, 0.28);
  color: var(--ok);
}

.bubble-pending {
  border-style: dashed;
  opacity: 0.7;
}

.bubble-pending .bubble-text {
  animation: dots 1.1s ease-in-out infinite;
}

.round-arrow {
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  height: 100%;
}

.round-line {
  position: relative;
  width: 100%;
  height: 1px;
  background: linear-gradient(90deg, var(--accent), var(--ok));
}

.round-line::after {
  content: "";
  position: absolute;
  right: -1px;
  top: 50%;
  width: 6px;
  height: 6px;
  border-top: 1.5px solid var(--ok);
  border-right: 1.5px solid var(--ok);
  transform: translateY(-50%) rotate(45deg);
}

.round-line.pending {
  background: repeating-linear-gradient(90deg,
      var(--border-hi) 0 4px,
      transparent 4px 8px);
  animation: shimmer 1.2s linear infinite;
}

.round-line.pending::after {
  border-color: var(--border-hi);
}

.round-ms {
  font-family: var(--font-mono);
  font-size: 0.72em;
  color: var(--muted);
  white-space: nowrap;
  letter-spacing: 0.02em;
}

@keyframes dots {

  0%,
  100% {
    opacity: 0.4;
  }

  50% {
    opacity: 1;
  }
}

@keyframes shimmer {
  from {
    background-position: 0 0;
  }

  to {
    background-position: 24px 0;
  }
}
</style>
