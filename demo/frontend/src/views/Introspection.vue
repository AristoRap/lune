<script setup>
import { ref } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { lune } from "../lune.js";

const Introspection = lune.Introspection;

const summary = ref("");
const procedures = ref([]);
const wrapperOut = ref("");

// The typed binding: `lune.Introspection.manifest()` returns a `Manifest`
// interface generated into `lunejs/runtime/runtime.d.ts` — the whole RPC
// contract as structured data, the same shape `lune doctor api` prints.
async function loadTyped() {
  const m = await Introspection.manifest();
  summary.value = `${m.procedures.length} procedures, ${m.types.length} types`;
  procedures.value = m.procedures.slice(0, 8).map((p) => p.name);
}

// The devtools convenience wrapper: `window.__lune.manifest()`. The plugin only
// injects it when the app runs with devtools on (auto-on under `lune dev`), so
// it's absent in a production build.
async function loadWrapper() {
  const fn = window.__lune?.manifest;
  if (!fn) {
    wrapperOut.value = "window.__lune.manifest is absent (devtools off).";
    return;
  }
  const m = await fn();
  wrapperOut.value = `${m.procedures.length} procedures via window.__lune.manifest()`;
}
</script>

<template>
  <SectionHead eyebrow="Runtime" title="Introspection">
    <template #desc>
      A built-in plugin (<code>src/lune/plugins/introspection.cr</code>) that
      exposes the app's live RPC contract — the <code>Vow::Manifest</code> of
      every procedure and the custom types its signatures reference. Reach it
      two ways: the typed <code>lune.Introspection.manifest()</code> binding
      (returns a generated <code>Manifest</code> interface), or the
      <code>window.__lune.manifest()</code> devtools wrapper the plugin injects
      under <code>lune dev</code>. The same contract is available from the CLI
      via <code>lune doctor api</code>. Disable it in <code>lune.yml</code>
      (<code>plugins.disabled: [introspection]</code>) like any built-in.
    </template>
  </SectionHead>

  <div class="card-grid">
    <div class="card">
      <span class="card-label">lune.Introspection.manifest() — <code>Promise&lt;Manifest&gt;</code></span>
      <button class="primary" @click="loadTyped">Introspect contract</button>
      <pre class="result mono">{{ summary }}</pre>
      <div class="proc-list">
        <div v-for="(name, i) in procedures" :key="i" class="proc">{{ name }}</div>
        <div v-if="procedures.length" class="proc muted">…</div>
      </div>
    </div>

    <div class="card">
      <span class="card-label">window.__lune.manifest() <em>(devtools only)</em></span>
      <button @click="loadWrapper">Call devtools wrapper</button>
      <pre class="result mono">{{ wrapperOut }}</pre>
    </div>
  </div>
</template>

<style scoped>
.proc-list {
  display: flex;
  flex-direction: column;
  gap: 0.2em;
  font-family: var(--font-mono);
  font-size: 0.82em;
  margin-top: 0.6em;
}

.proc {
  padding: 0.25em 0.5em;
  border-bottom: 1px solid var(--border);
}

.proc:last-child {
  border-bottom: none;
}

.proc.muted {
  color: var(--muted);
}
</style>
