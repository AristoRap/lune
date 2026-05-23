<script setup>
import { ref, onMounted } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { lune } from "../lune.js";
const { Kv } = lune;

const setKey = ref("theme");
const setValue = ref("dark");
const setBusy = ref(false);
const setResult = ref(null);

const getKey = ref("theme");
const getResult = ref(undefined);
const getBusy = ref(false);

const delKey = ref("");
const delBusy = ref(false);

const allKeys = ref([]);
const allBusy = ref(false);

const clearBusy = ref(false);

async function refresh() {
  allBusy.value = true;
  try {
    allKeys.value = await Kv.keys();
  } finally {
    allBusy.value = false;
  }
}

onMounted(refresh);

async function doSet() {
  if (setBusy.value) return;
  setBusy.value = true;
  setResult.value = null;
  try {
    let val;
    try { val = JSON.parse(setValue.value); } catch { val = setValue.value; }
    await Kv.set(setKey.value.trim(), val);
    setResult.value = { ok: true };
    await refresh();
  } catch (err) {
    setResult.value = { error: err.message || String(err) };
  } finally {
    setBusy.value = false;
  }
}

async function doGet() {
  if (getBusy.value) return;
  getBusy.value = true;
  getResult.value = undefined;
  try {
    getResult.value = await Kv.get(getKey.value.trim());
  } catch (err) {
    getResult.value = { __error: err.message || String(err) };
  } finally {
    getBusy.value = false;
  }
}

async function doDelete() {
  if (delBusy.value || !delKey.value.trim()) return;
  delBusy.value = true;
  try {
    await Kv.delete(delKey.value.trim());
    delKey.value = "";
    await refresh();
  } finally {
    delBusy.value = false;
  }
}

async function doClear() {
  if (clearBusy.value) return;
  clearBusy.value = true;
  try {
    await Kv.clear();
    getResult.value = undefined;
    await refresh();
  } finally {
    clearBusy.value = false;
  }
}

function display(val) {
  if (val === undefined) return "—";
  if (val === null) return "null";
  if (typeof val === "string") return `"${val}"`;
  return JSON.stringify(val, null, 2);
}
</script>

<template>
  <SectionHead eyebrow="Storage" title="KV">
    <template #desc>
      Persistent key-value store scoped to your app. Values survive app restarts
      and are stored as JSON in the app data directory.
      Use it for preferences, session state, and config.
    </template>
  </SectionHead>

  <div class="card-grid">
    <!-- Set -->
    <div class="card">
      <span class="card-label">Kv.set</span>
      <div class="field-row">
        <label class="field-label">Key</label>
        <input v-model="setKey" type="text" placeholder="key" @keydown.enter="doSet" />
      </div>
      <div class="field-row">
        <label class="field-label">Value</label>
        <input v-model="setValue" type="text" placeholder='string or JSON (e.g. 42, true, [1,2])' @keydown.enter="doSet" />
      </div>
      <button class="primary" :disabled="setBusy || !setKey.trim()" @click="doSet">
        {{ setBusy ? "Saving…" : "Set" }}
      </button>
      <div v-if="setResult?.ok" class="result-ok">Saved.</div>
      <div v-else-if="setResult?.error" class="result-err">{{ setResult.error }}</div>
    </div>

    <!-- Get -->
    <div class="card">
      <span class="card-label">Kv.get</span>
      <div class="field-row">
        <label class="field-label">Key</label>
        <input v-model="getKey" type="text" placeholder="key" @keydown.enter="doGet" />
      </div>
      <button class="primary" :disabled="getBusy || !getKey.trim()" @click="doGet">
        {{ getBusy ? "Getting…" : "Get" }}
      </button>
      <pre v-if="getResult !== undefined" class="result-pre"
        :class="{ err: getResult?.__error }">{{ getResult?.__error ? getResult.__error : display(getResult) }}</pre>
    </div>

    <!-- All keys -->
    <div class="card">
      <span class="card-label">Kv.keys</span>
      <div class="btn-row">
        <button class="secondary" :disabled="allBusy" @click="refresh">
          {{ allBusy ? "Loading…" : "Refresh" }}
        </button>
        <button class="danger" :disabled="clearBusy || !allKeys.length" @click="doClear">
          {{ clearBusy ? "Clearing…" : "Kv.clear" }}
        </button>
      </div>
      <div v-if="!allKeys.length" class="log-empty">Store is empty.</div>
      <div v-else class="key-list">
        <div v-for="k in allKeys" :key="k" class="key-row">
          <span class="key-name">{{ k }}</span>
          <button class="danger small" :disabled="delBusy" @click="delKey = k; doDelete()">Delete</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.field-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.field-label {
  font-size: 0.78em;
  font-weight: 600;
  letter-spacing: 0.04em;
  color: var(--muted);
  text-transform: uppercase;
  width: 3.5rem;
  flex-shrink: 0;
}

.btn-row {
  display: flex;
  gap: 0.6rem;
  margin-bottom: 0.5rem;
}

.result-pre {
  margin-top: 0.65rem;
  padding: 0.5rem 0.65rem;
  background: rgba(0, 0, 0, 0.25);
  border: 1px solid var(--border);
  border-radius: 6px;
  font-family: var(--font-mono);
  font-size: 0.82em;
  white-space: pre-wrap;
  word-break: break-all;
  max-height: 160px;
  overflow-y: auto;
}

.result-pre.err {
  border-color: var(--err, #f87171);
  color: var(--err, #f87171);
}

.result-ok {
  margin-top: 0.5rem;
  font-size: 0.82em;
  color: var(--ok, #34d399);
}

.result-err {
  margin-top: 0.5rem;
  font-size: 0.82em;
  color: var(--err, #f87171);
}

.key-list {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  margin-top: 0.5rem;
}

.key-row {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid var(--border);
  font-size: 0.83em;
}

.key-name {
  font-family: var(--font-mono);
  flex: 1;
  color: var(--fg, #e2e8f0);
}

.log-empty {
  margin-top: 0.5rem;
  font-size: 0.82em;
  color: var(--muted);
  font-style: italic;
}
</style>
