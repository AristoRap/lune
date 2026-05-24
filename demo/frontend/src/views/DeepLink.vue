<script setup>
import { ref, onMounted, onBeforeUnmount } from "vue";
import SectionHead from "../components/SectionHead.vue";

const lastUrl = ref(null);
const log = ref([]);

// Display-only handler: shows the URL and appends to the log. Navigation for
// `lune-demo://navigate/<id>` lives in App.vue so it works regardless of
// which view is mounted (including the cold-start home view).
function handleDeepLink(data) {
  const url = data.url;
  lastUrl.value = url;
  log.value.unshift({ url, ts: new Date().toLocaleTimeString() });
}

const handler = (data) => handleDeepLink(data);
onMounted(() => window.__lune.on("deep_link", handler, -1));
onBeforeUnmount(() => window.__lune.off("deep_link", handler));

function simulate() {
  window.__lune.crystalEmit("deep_link", { url: "lune-demo://open/path?token=demo123" });
}

function simulateNavigate() {
  window.__lune.crystalEmit("deep_link", { url: "lune-demo://navigate/windows" });
}
</script>

<template>
  <SectionHead eyebrow="Native" title="Deep Links">
    <template #desc>
      Register a custom URL scheme so the OS routes
      <code>lune-demo://...</code> links into this app. Use
      <code>DeepLink.on(cb)</code> to receive them.
    </template>
  </SectionHead>

  <div class="card-grid">
    <div class="card">
      <span class="card-label">Last received URL</span>
      <div class="url-display" :class="{ 'url-display--empty': !lastUrl }">
        {{ lastUrl ?? "Waiting for a deep link…" }}
      </div>
      <p class="hint">
        Fires when the OS routes a <code>lune-demo://</code> URL to this app.
      </p>
    </div>

    <div class="card">
      <span class="card-label">Simulate (dev / build)</span>
      <div class="btn-col">
        <button class="primary" @click="simulate">Fire lune-demo://open/path?token=demo123</button>
        <button class="primary" @click="simulateNavigate">Fire lune-demo://navigate/windows</button>
      </div>
      <p class="hint">
        <code>navigate/&lt;id&gt;</code> routes the app directly to that view.
        Calls <code>window.__lune.crystalEmit</code> directly — works in both
        <code>lune dev</code> and <code>lune build</code>.
      </p>
    </div>

    <div class="card">
      <span class="card-label">OS-level test (after <code>lune build</code>)</span>
      <div class="code-block">
        <span class="code-comment"># macOS — open a URL from Terminal</span>
        <span class="code-line">open "lune-demo://open/path?token=abc123"</span>
        <span class="code-comment mt"># Linux — after registering the .desktop file</span>
        <span class="code-line">xdg-open "lune-demo://open/path?token=abc123"</span>
      </div>
      <p class="hint">
        The app must be built (<code>lune build</code>) and launched at least
        once for macOS to register the scheme. Deep links during
        <code>lune dev</code> don't go through the OS.
      </p>
    </div>

    <div class="card">
      <span class="card-label">Event log</span>
      <div class="log">
        <div v-if="!log.length" class="log-empty">No deep links received yet…</div>
        <div v-for="(entry, i) in log" :key="i" class="log-entry">
          <span class="log-ts">{{ entry.ts }}</span>
          <span class="log-url">{{ entry.url }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.url-display {
  font-family: var(--font-mono);
  font-size: 0.9em;
  padding: 0.6rem 0.75rem;
  border-radius: 6px;
  background: rgba(167, 139, 250, 0.1);
  border: 1px solid rgba(167, 139, 250, 0.28);
  color: var(--moon-2);
  word-break: break-all;
}

.url-display--empty {
  color: var(--muted);
  background: var(--surface-hi);
  border-color: var(--border);
}

.code-block {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  font-family: var(--font-mono);
  font-size: 0.82em;
  padding: 0.75rem;
  background: var(--surface-hi);
  border: 1px solid var(--border);
  border-radius: 6px;
}

.code-comment {
  color: var(--muted);
  font-style: italic;
}

.btn-col {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.code-comment.mt {
  margin-top: 0.5rem;
}

.code-line {
  color: var(--fg);
  user-select: all;
}

.log {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  max-height: 180px;
  overflow-y: auto;
}

.log-entry {
  display: flex;
  gap: 0.75rem;
  font-family: var(--font-mono);
  font-size: 0.82em;
  align-items: baseline;
}

.log-ts {
  color: var(--muted);
  white-space: nowrap;
  flex-shrink: 0;
}

.log-url {
  color: var(--moon-2);
  word-break: break-all;
}
</style>
