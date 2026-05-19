<script setup>
import { ref } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { Stream } from "../lune.js";

// ------- live ticker (Crystal → JS) -------

const streaming = ref(false);
const prices = ref({
  BTC:  { price: 45000, change: 0 },
  ETH:  { price: 2800,  change: 0 },
  SOL:  { price: 120,   change: 0 },
  AAPL: { price: 185,   change: 0 },
  MSFT: { price: 380,   change: 0 },
});
const msgPerSec = ref(0);
let secCount = 0;
setInterval(() => { msgPerSec.value = secCount; secCount = 0; }, 1000);

Stream.on("tick", ({ symbol, price, change }) => {
  prices.value[symbol] = { price, change };
  secCount++;
});

function toggleStream() {
  streaming.value = !streaming.value;
  Stream.send(streaming.value ? "stream-start" : "stream-stop");
}

// ------- stream ping/pong (JS → Crystal → JS) -------

const pingValue = ref("hello");
const rounds = ref([]);
let nextId = 1;

Stream.on("stream-pong", (data) => {
  const pending = rounds.value.find((r) => r.pong === undefined);
  if (pending) {
    pending.pong = data;
    pending.ms = performance.now() - pending.sentAt;
  }
});

function sendPing() {
  rounds.value.push({ id: nextId++, ping: pingValue.value, pong: undefined, sentAt: performance.now(), ms: 0 });
  Stream.send("stream-ping", pingValue.value);
}
</script>

<template>
  <SectionHead eyebrow="High-throughput" title="Stream">
    <template #desc>
      A WebSocket-backed IPC stream for ordered, low-latency data delivery.
      Use it for streaming data or high-frequency events where the event bus
      would saturate with per-message <code>evaluateJavaScript</code> calls.
    </template>
  </SectionHead>

  <div class="card-grid">
    <div class="card">
      <span class="card-label">Live ticker — Crystal → JS (~20 msg/s)</span>
      <div class="ticker-controls">
        <button :class="streaming ? 'danger' : 'primary'" @click="toggleStream">
          {{ streaming ? "Stop stream" : "Start stream" }}
        </button>
        <span class="badge" :class="streaming ? 'badge--live' : ''">
          <span v-if="streaming" class="live-dot"></span>
          {{ streaming ? `${msgPerSec} msg/s` : "idle" }}
        </span>
      </div>
      <table class="ticker-table">
        <thead>
          <tr><th>Symbol</th><th>Price</th><th>Change</th></tr>
        </thead>
        <tbody>
          <tr v-for="(d, sym) in prices" :key="sym">
            <td class="sym">{{ sym }}</td>
            <td class="price">${{ d.price.toFixed(2) }}</td>
            <td class="chg" :class="d.change >= 0 ? 'pos' : 'neg'">
              {{ d.change >= 0 ? "+" : "" }}{{ d.change.toFixed(4) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <span class="card-label">Stream ping — JS → Crystal → JS</span>
      <div class="row">
        <input v-model="pingValue" type="text" @keydown.enter="sendPing" />
        <button class="primary" @click="sendPing">Send</button>
      </div>
      <p class="hint">
        Uses <code>Stream.send</code> / <code>app.stream.on</code> — fire-and-forget,
        no <code>await</code> needed.
      </p>
      <div class="rounds">
        <div v-if="!rounds.length" class="log-empty">Send a message to see the round trip…</div>
        <div v-for="r in rounds" :key="r.id" class="round">
          <span class="round-index">#{{ r.id }}</span>
          <span class="bubble bubble-out">
            <span class="bubble-tag">SEND</span>
            <span class="bubble-text">{{ r.ping }}</span>
          </span>
          <span class="round-arrow">
            <span class="round-line" :class="{ pending: r.pong === undefined }"></span>
          </span>
          <span class="bubble bubble-in" :class="{ 'bubble-pending': r.pong === undefined }">
            <span class="bubble-tag">RECV</span>
            <span class="bubble-text">
              <template v-if="r.pong !== undefined">{{ r.pong }}</template>
              <template v-else>…</template>
            </span>
          </span>
          <span v-if="r.pong !== undefined" class="round-ms">{{ r.ms.toFixed(1) }} ms</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.ticker-controls {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}

.live-dot {
  width: 6px;
  height: 6px;
  border-radius: 99px;
  background: var(--ok);
  box-shadow: 0 0 8px rgba(52, 211, 153, 0.7);
  display: inline-block;
}

.ticker-table {
  width: 100%;
  border-collapse: collapse;
  font-family: var(--font-mono);
  font-size: 0.85em;
}

.ticker-table th {
  text-align: left;
  color: var(--muted);
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  font-size: 0.72em;
  padding: 0 0 0.4rem;
  border-bottom: 1px solid var(--border);
}

.ticker-table td {
  padding: 0.35rem 0;
  border-bottom: 1px solid var(--border-lo, rgba(255,255,255,0.04));
}

.sym   { color: var(--fg); font-weight: 700; }
.price { color: var(--moon-2); text-align: right; padding-right: 1rem; }
.chg   { text-align: right; }
.pos   { color: var(--ok); }
.neg   { color: var(--err, #f87171); }

/* reuse ping/pong styles from events */
.rounds {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  max-height: 200px;
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
  background: linear-gradient(135deg, rgba(167,139,250,0.18), rgba(124,108,255,0.1));
  border-color: rgba(167,139,250,0.32);
  color: var(--moon-2);
  justify-content: flex-end;
}

.bubble-in {
  background: rgba(52,211,153,0.08);
  border-color: rgba(52,211,153,0.28);
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
}

.round-line {
  width: 100%;
  height: 1px;
  background: linear-gradient(90deg, var(--accent), var(--ok));
  position: relative;
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
  background: repeating-linear-gradient(90deg, var(--border-hi) 0 4px, transparent 4px 8px);
  animation: shimmer 1.2s linear infinite;
}

.round-line.pending::after { border-color: var(--border-hi); }

.round-ms {
  font-family: var(--font-mono);
  font-size: 0.72em;
  color: var(--muted);
  white-space: nowrap;
}

@keyframes dots { 0%, 100% { opacity: 0.4; } 50% { opacity: 1; } }
@keyframes shimmer { from { background-position: 0 0; } to { background-position: 24px 0; } }
</style>
