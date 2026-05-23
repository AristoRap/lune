<script setup>
import { onMounted, ref } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { MyCustomPlugin } from "../lune.js";
import { useLuneEvent } from "../composables/useLuneEvent.js";
// `CounterState` is a named TypeScript interface generated into
// `lunejs/runtime/runtime.d.ts` from the `@[Lune::TsType]`-annotated
// `CounterState` Crystal struct in `demo/src/counter.cr`. Importing the
// type by name is the whole point of `@[Lune::TsType]` — without the
// annotation the return shape would be `Promise<Record<string, any>>`.
// eslint-disable-next-line no-unused-vars
/** @typedef {import("../lunejs/runtime/runtime.js").CounterState} CounterState */

const Counter = MyCustomPlugin.Counter;
const state = ref(/** @type {CounterState | null} */(null));
const log = ref([]);

// `Counter` is a custom plugin defined in `demo/src/counter.cr` and registered
// via `Lune.use(Counter.new)` in `demo/src/main.cr`. Third-party plugins are
// top-level exports on `lune.js` — alongside `lune` (Lune.Plugins), not under
// it.
onMounted(async () => {
  state.value = await Counter.state();
});

useLuneEvent("counter:changed", async (data) => {
  state.value = await Counter.state();
  log.value.unshift({ t: new Date().toLocaleTimeString(), v: data.value });
  log.value = log.value.slice(0, 8);
});

async function inc() {
  await Counter.increment();
}
async function dec() {
  await Counter.decrement();
}
async function reset() {
  await Counter.reset();
}
</script>

<template>
  <SectionHead eyebrow="Custom plugin" title="Counter">
    <template #desc>
      A plugin defined in <code>demo/src/counter.cr</code> and registered with
      <code>Lune.use(Counter.new)</code>. Crystal-side state, five
      <code>@[Lune::Bind]</code> methods, a <code>config do</code> block
      that lets <code>opts.counter.start_at</code> and
      <code>opts.counter.step</code> seed the counter from the
      <code>Lune.run</code> block (set to <code>100</code> and <code>5</code>
      here), and a <code>@[Lune::TsType]</code>-annotated
      <code>CounterState</code> struct returned from <code>Counter.state()</code> —
      a named TS interface in <code>lunejs/runtime/runtime.d.ts</code>, not an
      anonymous shape. Every change emits <code>"counter:changed"</code> so
      the UI stays in sync.
    </template>
  </SectionHead>

  <div class="card-grid">
    <div class="card">
      <span class="card-label">Value</span>
      <div class="counter-value">{{ state === null ? "—" : state.value }}</div>
      <div class="row">
        <button @click="dec">−5</button>
        <button class="primary" @click="inc">+5</button>
        <button @click="reset">Reset</button>
      </div>
    </div>

    <div class="card">
      <span class="card-label">Typed state — <code>Promise&lt;CounterState&gt;</code></span>
      <div v-if="state" class="state-grid">
        <div class="state-row"><span class="state-key">value</span><span class="state-val">{{ state.value }}</span>
        </div>
        <div class="state-row"><span class="state-key">step</span><span class="state-val">{{ state.step }}</span></div>
        <div class="state-row"><span class="state-key">at_default</span><span class="state-val">{{ state.at_default
            }}</span></div>
      </div>
      <div v-else class="log-empty">Loading…</div>
    </div>

    <div class="card">
      <span class="card-label">Change log (via <code>counter:changed</code> event)</span>
      <div class="log">
        <div v-if="!log.length" class="log-empty">Click + or − to fire events…</div>
        <div v-for="(e, i) in log" :key="i" class="log-entry">
          <span class="time">{{ e.t }}</span>
          <span class="val">{{ e.v }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.counter-value {
  font-family: var(--font-mono);
  font-size: 3.2em;
  font-weight: 700;
  text-align: center;
  padding: 0.4em 0;
  background: linear-gradient(135deg, var(--moon-2), var(--accent));
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
  letter-spacing: 0.02em;
}

.log {
  font-family: var(--font-mono);
  font-size: 0.85em;
  max-height: 180px;
  overflow-y: auto;
}

.log-entry {
  display: flex;
  justify-content: space-between;
  padding: 0.3em 0.5em;
  border-bottom: 1px solid var(--border);
}

.log-entry:last-child {
  border-bottom: none;
}

.time {
  color: var(--muted);
}

.val {
  font-weight: 600;
}

.state-grid {
  display: flex;
  flex-direction: column;
  gap: 0.3em;
  font-family: var(--font-mono);
  font-size: 0.9em;
}

.state-row {
  display: flex;
  justify-content: space-between;
  padding: 0.35em 0.6em;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: rgba(167, 139, 250, 0.06);
}

.state-key {
  color: var(--muted);
  letter-spacing: 0.02em;
}

.state-val {
  font-weight: 600;
  color: var(--moon-2);
}
</style>
