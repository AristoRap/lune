<script setup>
import { onMounted, ref } from "vue";
import SectionHead from "../components/SectionHead.vue";

// Availability is detected uniformly via window["capabilities.__lune.<cap>"] === true.
// The runner injects this sentinel for every active capability before calling init_webview,
// so excluded capabilities leave no footprint. fns is display-only.
const CAP_NS = "capabilities.__lune";

const ALL = [
  // Bridge — callable bindings registered over the bridge
  { cap: "system", group: "System", core: false, fns: ["quit", "openUrl", "environment"] },
  { cap: "filesystem", group: "Filesystem", core: false, fns: ["homeDir", "appDataDir", "downloadsDir", "tempDir"] },
  { cap: "clipboard", group: "Clipboard", core: false, fns: ["read", "write", "readHtml", "writeHtml", "readImage", "writeImage"] },
  { cap: "window", group: "Window", core: false, fns: ["minimize", "maximize", "center", "setTitle", "setSize"] },
  { cap: "dialogs", group: "Dialogs", core: false, fns: ["openFile", "openDir", "openFiles", "saveFile", "messageInfo", "messageWarning", "messageError", "messageQuestion"] },
  { cap: "tray", group: "Tray", core: false, fns: ["show", "hide", "setIcon", "setMenu"] },
  { cap: "notifications", group: "Notifications", core: false, fns: ["notify"] },
  { cap: "screen", group: "Screen", core: false, fns: ["info"] },
  { cap: "context_menu", group: "Context Menu", core: false, fns: ["set", "clear", "onSelect"] },
  { cap: "drag_out", group: "Drag Out", core: false, fns: ["start"] },
  // Core — JS-injected infrastructure, no bridge binding
  { cap: "event_bus", group: "Event Bus", core: true, fns: ["on", "once", "off", "emit"] },
  { cap: "deep_link", group: "Deep Link", core: true, fns: ["onDeepLink", "onDeepLinkOff"] },
  { cap: "file_drop", group: "File Drop", core: true, fns: ["on", "off"] },
  { cap: "keyboard_shortcuts", group: "Keyboard Shortcuts", core: true, fns: ["Cmd/Ctrl+C/V/X/Z/Y"] },
];

const bridgeGroups = ref([]);
const coreGroups = ref([]);
const restricted = ref(false);

onMounted(() => {
  const resolve = (g) => ({
    cap: g.cap,
    group: g.group,
    available: window[`${CAP_NS}.${g.cap}`] === true,
    fns: g.fns,
  });

  bridgeGroups.value = ALL.filter((g) => !g.core).map(resolve);
  coreGroups.value = ALL.filter((g) => g.core).map(resolve);
  restricted.value = bridgeGroups.value.some((g) => !g.available);
});
</script>

<template>
  <SectionHead eyebrow="Security" title="Capabilities"
    desc="Restrict which capabilities are active by listing their group names in lune.yml. Excluded capabilities are stripped from the bridge and runtime.js at build time." />

  <div class="status-banner" :class="restricted ? 'warn' : 'ok'">
    <span class="dot"></span>
    <span v-if="restricted">Some capabilities are restricted in this build.</span>
    <span v-else>All runtime capabilities are available — no restrictions configured.</span>
  </div>

  <p class="section-label">Bridge capabilities</p>
  <div class="cap-grid">
    <div v-for="g in bridgeGroups" :key="g.cap" class="card" :class="g.available ? '' : 'card-off'">
      <span class="card-label">{{ g.group }} <code class="cap-name">{{ g.cap }}</code></span>
      <ul class="fn-list">
        <li v-for="fn in g.fns" :key="fn" :class="g.available ? 'ok' : 'off'">
          <span class="indicator"></span>
          <code>{{ fn }}()</code>
        </li>
      </ul>
    </div>
  </div>

  <p class="section-label">Core capabilities <span class="section-note">(JS-injected, no bridge binding)</span></p>
  <div class="cap-grid">
    <div v-for="g in coreGroups" :key="g.cap" class="card" :class="g.available ? '' : 'card-off'">
      <span class="card-label">{{ g.group }} <code class="cap-name">{{ g.cap }}</code></span>
      <ul class="fn-list">
        <li v-for="fn in g.fns" :key="fn" :class="g.available ? 'ok' : 'off'">
          <span class="indicator"></span>
          <span class="fn-text">{{ fn }}</span>
        </li>
      </ul>
    </div>
  </div>

  <div class="config-block card">
    <span class="card-label">lune.yml — restrict to specific capabilities</span>
    <pre class="mono">capabilities:
  include:
    - lifecycle
    - clipboard
    - notifications

# or exclude a group while keeping everything else:
capabilities:
  exclude:
    - dialogs
    - tray</pre>
    <p class="hint">
      <code>include</code>/<code>exclude</code> take <strong>capability group names</strong> (e.g.
      <code>lifecycle</code>, <code>clipboard</code>).
      Individual function names like <code>quit</code> are not valid — they log a warning and are ignored.
      Omit <code>capabilities</code> entirely to allow everything (the default).
    </p>
  </div>
</template>

<style scoped>
.section-label {
  font-size: 0.78em;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--muted);
  margin: 1.25rem 0 0.6rem;
}

.section-note {
  font-weight: 400;
  text-transform: none;
  letter-spacing: 0;
  font-size: 0.9em;
}

.card-off {
  opacity: 0.45;
}

.fn-text {
  font-size: 0.85em;
  color: var(--text-mid);
}

.status-banner {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.75rem 1rem;
  border-radius: var(--radius);
  font-size: 0.88em;
  margin-bottom: 1.25rem;
  border: 1px solid;
}

.status-banner.ok {
  background: rgba(52, 211, 153, 0.06);
  border-color: rgba(52, 211, 153, 0.25);
  color: #6ee7b7;
}

.status-banner.warn {
  background: rgba(251, 191, 36, 0.06);
  border-color: rgba(251, 191, 36, 0.25);
  color: #fcd34d;
}

.status-banner .dot {
  width: 7px;
  height: 7px;
  border-radius: 99px;
  flex-shrink: 0;
  background: currentColor;
}

.cap-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 0.9rem;
  margin-bottom: 1.25rem;
}

.fn-list {
  list-style: none;
  padding: 0;
  margin: 0.5rem 0 0;
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.fn-list li {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  font-size: 0.85em;
}

.fn-list li.ok {
  color: var(--text);
}

.fn-list li.off {
  color: var(--muted);
  text-decoration: line-through;
}

.indicator {
  width: 6px;
  height: 6px;
  border-radius: 99px;
  flex-shrink: 0;
}

.ok .indicator {
  background: #34d399;
}

.off .indicator {
  background: rgba(255, 255, 255, 0.18);
}

.config-block {
  margin-top: 0;
}

.config-block pre {
  margin: 0.6rem 0 0.75rem;
  padding: 0.85rem 1rem;
  background: rgba(0, 0, 0, 0.25);
  border: 1px solid var(--border);
  border-radius: 6px;
  font-size: 0.82em;
  line-height: 1.6;
  overflow-x: auto;
}

.hint {
  font-size: 0.82em;
  color: var(--text-mid);
  line-height: 1.55;
  margin: 0;
}

.hint code {
  font-family: var(--font-mono);
  color: var(--accent);
}

.cap-name {
  font-family: var(--font-mono);
  font-size: 0.72em;
  color: var(--muted);
  margin-left: 0.4rem;
  font-weight: 400;
}
</style>
