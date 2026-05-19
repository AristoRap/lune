<script setup>
import { ref, onMounted, onBeforeUnmount } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { Shell } from "../lune.js";

// ------- spawn mode: stream output live -------

const spawnCmd = ref("ping");
const spawnArgs = ref("-c 5 127.0.0.1");
const running = ref(false);
const currentPid = ref(null);
const lines = ref([]);  // { type: "stdout"|"stderr"|"exit", text: string }
let nextId = 1;

function pushLine(type, text) {
  lines.value.push({ id: nextId++, type, text });
  if (lines.value.length > 200) lines.value.shift();
}

async function runSpawn() {
  if (running.value) return;
  lines.value = [];
  running.value = true;

  const cmd = spawnCmd.value.trim();
  const argv = spawnArgs.value.trim() ? spawnArgs.value.trim().split(/\s+/) : [];

  let pid;
  try {
    pid = await Shell.spawn(cmd, argv);
  } catch (err) {
    pushLine("stderr", `Error: ${err.message || err}`);
    running.value = false;
    return;
  }

  currentPid.value = pid;
  Shell.listen(pid, {
    stdout: ({ line }) => pushLine("stdout", line),
    stderr: ({ line }) => pushLine("stderr", line),
    exit: ({ code }) => {
      pushLine("exit", `Process exited with code ${code}`);
      running.value = false;
      currentPid.value = null;
    },
  });
}

function killProcess() {
  if (currentPid.value) Shell.kill(currentPid.value);
}

// ------- background processes (started in another window) -------

const backgroundPids = ref([]);

onMounted(async () => {
  try {
    const all = await Shell.list();
    // filter out the one already tracked locally
    const foreign = all.filter(p => p !== currentPid.value);
    backgroundPids.value = foreign;
    for (const pid of foreign) {
      Shell.listen(pid, {
        stdout: ({ line }) => pushLine("stdout", `[${pid.slice(0, 6)}] ${line}`),
        stderr: ({ line }) => pushLine("stderr", `[${pid.slice(0, 6)}] ${line}`),
        exit: ({ code }) => {
          backgroundPids.value = backgroundPids.value.filter(p => p !== pid);
          pushLine("exit", `[${pid.slice(0, 6)}] exited (${code})`);
        },
      });
    }
  } catch (_) { }
});

onBeforeUnmount(() => {
  for (const pid of backgroundPids.value) Shell.unlisten(pid);
});

// ------- run mode: collect all output, resolve on exit -------

const runCmd = ref("uname");
const runArgs = ref("-a");
const runResult = ref(null);
const runBusy = ref(false);

async function runOnce() {
  if (runBusy.value) return;
  runResult.value = null;
  runBusy.value = true;
  const cmd = runCmd.value.trim();
  const argv = runArgs.value.trim() ? runArgs.value.trim().split(/\s+/) : [];
  try {
    runResult.value = await Shell.run(cmd, argv);
  } catch (err) {
    runResult.value = { stdout: "", stderr: err.message || String(err), code: -1 };
  }
  runBusy.value = false;
}
</script>

<template>
  <SectionHead eyebrow="Process" title="Shell">
    <template #desc>
      Spawn child processes and stream <code>stdout</code>/<code>stderr</code>
      to the frontend in real time via the WebSocket Stream. Use
      <code>Shell.spawn</code> for live output or <code>Shell.run</code>
      to collect all output when the process exits.
    </template>
  </SectionHead>

  <div class="card-grid">
    <!-- Live spawn -->
    <div class="card">
      <span class="card-label">Shell.spawn — live output</span>

      <div class="field-row">
        <label class="field-label">Command</label>
        <input v-model="spawnCmd" type="text" :disabled="running" />
      </div>
      <div class="field-row">
        <label class="field-label">Args</label>
        <input v-model="spawnArgs" type="text" :disabled="running" placeholder="space-separated"
          @keydown.enter="runSpawn" />
      </div>

      <div class="btn-row">
        <button class="primary" :disabled="running" @click="runSpawn">Run</button>
        <button class="danger" :disabled="!running" @click="killProcess">Kill</button>
        <span v-if="running" class="badge badge--live">
          <span class="live-dot"></span> running
        </span>
      </div>

      <div class="terminal">
        <div v-if="!lines.length" class="log-empty">Output will appear here…</div>
        <div v-for="l in lines" :key="l.id" :class="['term-line', `term-${l.type}`]">
          {{ l.text }}
        </div>
      </div>
    </div>

    <!-- Background processes from other windows -->
    <div v-if="backgroundPids.length" class="card">
      <span class="card-label">Background processes</span>
      <p class="card-desc">Processes started in another window. Output streams here in real time.</p>
      <div class="bg-list">
        <div v-for="pid in backgroundPids" :key="pid" class="bg-row">
          <span class="badge badge--live"><span class="live-dot"></span> running</span>
          <code class="bg-pid">{{ pid }}</code>
          <button class="danger small" @click="Shell.kill(pid)">Kill</button>
        </div>
      </div>
    </div>

    <!-- Shell.run convenience -->
    <div class="card">
      <span class="card-label">Shell.run — collect on exit</span>

      <div class="field-row">
        <label class="field-label">Command</label>
        <input v-model="runCmd" type="text" :disabled="runBusy" />
      </div>
      <div class="field-row">
        <label class="field-label">Args</label>
        <input v-model="runArgs" type="text" :disabled="runBusy" placeholder="space-separated"
          @keydown.enter="runOnce" />
      </div>

      <button class="primary" :disabled="runBusy" @click="runOnce">
        {{ runBusy ? "Running…" : "Run" }}
      </button>

      <template v-if="runResult !== null">
        <div v-if="runResult.stdout" class="result-block result-stdout">
          <span class="result-label">stdout</span>
          <pre>{{ runResult.stdout }}</pre>
        </div>
        <div v-if="runResult.stderr" class="result-block result-stderr">
          <span class="result-label">stderr</span>
          <pre>{{ runResult.stderr }}</pre>
        </div>
        <div class="result-exit" :class="runResult.code === 0 ? 'ok' : 'err'">
          exit {{ runResult.code }}
        </div>
      </template>
      <div v-else-if="!runBusy" class="log-empty" style="margin-top:0.75rem">
        Run a command to see output…
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
  width: 4.5rem;
  flex-shrink: 0;
}

.btn-row {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  margin-bottom: 0.75rem;
}

.terminal {
  font-family: var(--font-mono);
  font-size: 0.82em;
  background: rgba(0, 0, 0, 0.3);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 0.6rem 0.75rem;
  max-height: 260px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}

.term-line {
  white-space: pre-wrap;
  word-break: break-all;
  line-height: 1.5;
}

.term-stdout {
  color: var(--fg, #e2e8f0);
}

.term-stderr {
  color: var(--err, #f87171);
}

.term-exit {
  color: var(--muted);
  font-style: italic;
}

.bg-list {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  margin-top: 0.5rem;
}

.bg-row {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  font-size: 0.82em;
}

.bg-pid {
  font-family: var(--font-mono);
  color: var(--muted);
  flex: 1;
}

.live-dot {
  width: 6px;
  height: 6px;
  border-radius: 99px;
  background: var(--ok);
  box-shadow: 0 0 8px rgba(52, 211, 153, 0.7);
  display: inline-block;
}

.result-block {
  margin-top: 0.65rem;
  border-radius: 6px;
  border: 1px solid var(--border);
  overflow: hidden;
}

.result-label {
  display: block;
  font-size: 0.72em;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  padding: 0.2rem 0.65rem;
  background: rgba(255, 255, 255, 0.04);
  border-bottom: 1px solid var(--border);
}

.result-stdout .result-label {
  color: var(--moon-2, #a5b4fc);
}

.result-stderr .result-label {
  color: var(--err, #f87171);
}

.result-block pre {
  margin: 0;
  padding: 0.5rem 0.65rem;
  font-family: var(--font-mono);
  font-size: 0.82em;
  white-space: pre-wrap;
  word-break: break-all;
  max-height: 140px;
  overflow-y: auto;
}

.result-exit {
  display: inline-block;
  margin-top: 0.5rem;
  font-family: var(--font-mono);
  font-size: 0.78em;
  font-weight: 700;
  padding: 0.2em 0.6em;
  border-radius: 4px;
}

.result-exit.ok {
  background: rgba(52, 211, 153, 0.1);
  color: var(--ok);
}

.result-exit.err {
  background: rgba(248, 113, 113, 0.1);
  color: var(--err, #f87171);
}
</style>
