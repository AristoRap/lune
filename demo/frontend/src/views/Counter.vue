<script setup>
import { onMounted, ref } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { MyCustomPlugin } from "../lune.js";
import { useLuneEvent } from "../composables/useLuneEvent.js";

const Counter = MyCustomPlugin.Counter;
const value = ref(null);
const log = ref([]);

// `Counter` is a custom plugin defined in `demo/src/counter.cr` and registered
// via `Lune.use(Counter.new)` in `demo/src/main.cr`. Third-party plugins are
// top-level exports on `lune.js` — alongside `lune` (Lune.Plugins), not under
// it.
onMounted(async () => {
  value.value = await Counter.value();
});

useLuneEvent("counter:changed", (data) => {
  value.value = data.value;
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
      <code>Lune.use(Counter.new)</code>. Crystal-side state, four
      <code>@[Lune::Bind]</code> methods, and a <code>config do</code> block
      that lets <code>opts.counter.start_at</code> and
      <code>opts.counter.step</code> seed the counter from the
      <code>Lune.run</code> block (set to <code>100</code> and <code>5</code>
      here). Every change emits <code>"counter:changed"</code> so the UI
      stays in sync.
    </template>
  </SectionHead>

  <div class="card-grid">
    <div class="card">
      <span class="card-label">Value</span>
      <div class="counter-value">{{ value === null ? "—" : value }}</div>
      <div class="row">
        <button @click="dec">−5</button>
        <button class="primary" @click="inc">+5</button>
        <button @click="reset">Reset</button>
      </div>
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
</style>
