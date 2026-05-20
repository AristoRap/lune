<script setup>
import { onMounted, ref } from "vue";
import luneSrc from "../assets/images/lune.svg";
import vueSrc from "../assets/images/vue.svg";
import Icon from "../components/Icon.vue";
import { System, Screen } from "../lune.js";

const env = ref(null);
const screen = ref(null);

onMounted(async () => {
  try {
    env.value = await System.environment();
    screen.value = await Screen.info();
  } catch (_) {
    /* unavailable in static preview */
  }
});

const features = [
  {
    icon: "code",
    title: "Type-safe bindings",
    body: "Annotate Crystal methods with @[Lune::Bind] and call them from JavaScript like ordinary async functions. Generated TypeScript-friendly shims live in lunejs/.",
  },
  {
    icon: "bolt",
    title: "Bidirectional events",
    body: "A tiny event bus connects Crystal and the WebView. Stream progress, push live data, or fan-in UI signals — all without HTTP plumbing.",
  },
  {
    icon: "window",
    title: "Native window",
    body: "Drive titles, sizes, drag zones, drop targets, and full-size content from your code. The native WebKit shell stays under your control.",
  },
  {
    icon: "tray",
    title: "OS integration",
    body: "File dialogs, message boxes, notifications, system tray, menu bars with shortcuts — every piece you'd expect from a desktop app.",
  },
];
</script>

<template>
  <div class="welcome">
    <section class="hero">
      <div class="hero-text">
        <span class="eyebrow">Crystal • WebKit • Vue</span>
        <h1>
          A tiny moon for
          <span class="grad">desktop apps</span>.
        </h1>
        <p class="lede">
          Lune wires a Crystal backend to a web frontend through a small,
          predictable API: bindings, events, runtime calls, native dialogs,
          and a custom menu bar. This app is a live tour of every piece.
        </p>
        <div class="hero-actions">
          <button class="btn-link primary" @click="System.openUrl('https://github.com/aristorap/lune')">
            <Icon name="code" :size="14" /> Source on GitHub
          </button>
          <span class="chip">
            <span class="chip-key">os</span>
            <span class="chip-val">{{ env?.os || "—" }}</span>
          </span>
          <span class="chip">
            <span class="chip-key">arch</span>
            <span class="chip-val">{{ env?.arch || "—" }}</span>
          </span>
          <span class="chip">
            <span class="chip-key">build</span>
            <span class="chip-val">
              {{ env?.devtools === undefined ? "—" : env.devtools ? "dev" : "release" }}
            </span>
          </span>
        </div>
      </div>

      <div class="hero-art">
        <div class="orbit">
          <img :src="luneSrc" class="planet" alt="Lune" />
          <img :src="vueSrc" class="satellite sat-vue" alt="Vue" />
          <span class="satellite sat-c">Cr</span>
          <span class="satellite sat-js">JS</span>
          <span class="orbit-ring ring-1"></span>
          <span class="orbit-ring ring-2"></span>
        </div>
      </div>
    </section>

    <section class="features card-grid">
      <article v-for="f in features" :key="f.title" class="feature">
        <div class="feature-icon">
          <Icon :name="f.icon" :size="18" />
        </div>
        <h3>{{ f.title }}</h3>
        <p>{{ f.body }}</p>
      </article>
    </section>

    <section class="stats">
      <div class="stat">
        <span class="stat-key">os</span>
        <span class="stat-val">{{ env?.os || "—" }}</span>
      </div>
      <div class="stat">
        <span class="stat-key">arch</span>
        <span class="stat-val">{{ env?.arch || "—" }}</span>
      </div>
      <div class="stat">
        <span class="stat-key">display</span>
        <span class="stat-val">
          {{ screen ? `${screen.width}×${screen.height}` : "—" }}
        </span>
      </div>
      <div class="stat">
        <span class="stat-key">scale</span>
        <span class="stat-val">{{ screen?.scale ? `${screen.scale}×` : "—" }}</span>
      </div>
    </section>

    <section class="callout">
      <div>
        <span class="eyebrow">tip</span>
        <p>
          Pick any section from the sidebar to see the underlying Lune API in
          action. Code samples are included where it helps. Press
          <kbd>⌘</kbd><kbd>R</kbd> to reload the shell anytime.
        </p>
      </div>
    </section>
  </div>
</template>

<style scoped>
.welcome {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.hero {
  display: grid;
  grid-template-columns: 1.4fr 1fr;
  gap: 2rem;
  align-items: center;
  padding: 1.5rem 0 1rem;
}

@media (max-width: 880px) {
  .hero {
    grid-template-columns: 1fr;
  }
}

.eyebrow {
  display: inline-block;
  font-size: 0.7em;
  text-transform: uppercase;
  letter-spacing: 0.22em;
  color: var(--accent);
  font-weight: 700;
  margin-bottom: 0.5rem;
}

.hero-text h1 {
  font-size: clamp(1.9rem, 3.2vw, 2.6rem);
  line-height: 1.05;
  font-weight: 700;
  margin: 0 0 0.85rem;
  letter-spacing: -0.02em;
}

.hero-text h1 .grad {
  background: linear-gradient(135deg, var(--moon-1), var(--accent) 50%, var(--moon-3));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.lede {
  color: var(--text-mid);
  font-size: 1em;
  line-height: 1.6;
  max-width: 56ch;
  margin-bottom: 1.2rem;
}

.hero-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.btn-link {
  display: inline-flex;
  align-items: center;
  gap: 0.4em;
  border-radius: 7px;
  padding: 0.5em 1em;
  font-size: 0.88em;
  font-weight: 600;
  border: 1px solid transparent;
  background: linear-gradient(135deg, var(--accent), var(--accent-2));
  color: #0a0a1a;
  text-decoration: none;
  box-shadow: 0 6px 22px -8px var(--accent-glow);
  transition: filter 200ms;
}

.btn-link:hover {
  filter: brightness(1.08);
  text-decoration: none;
}

.chip {
  display: inline-flex;
  align-items: center;
  gap: 0.45em;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--border);
  border-radius: 99px;
  padding: 0.3em 0.75em;
  font-size: 0.78em;
}

.chip-key {
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-size: 0.85em;
}

.chip-val {
  color: var(--text);
  font-family: var(--font-mono);
}

/* hero art */
.hero-art {
  position: relative;
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 280px;
}

.orbit {
  position: relative;
  width: 280px;
  height: 280px;
  display: grid;
  place-items: center;
}

.planet {
  width: 130px;
  height: 130px;
  filter: drop-shadow(0 0 36px var(--accent-glow));
  animation: float 7s ease-in-out infinite;
}

.satellite {
  position: absolute;
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 99px;
  background: rgba(11, 13, 28, 0.85);
  border: 1px solid var(--border-hi);
  font-size: 0.72em;
  font-weight: 700;
  color: var(--text);
  font-family: var(--font-display);
  letter-spacing: 0.02em;
  box-shadow: var(--shadow-1);
}

.satellite.sat-vue {
  background: #1a2233;
  padding: 8px;
}

.satellite.sat-c {
  color: #ff8c8c;
}

.satellite.sat-js {
  color: #fbd34d;
}

.sat-vue,
.sat-c,
.sat-js {
  animation: orbit 18s linear infinite;
}

.sat-vue {
  --r: 130px;
  --d: 0s;
}

.sat-c {
  --r: 130px;
  --d: -6s;
}

.sat-js {
  --r: 130px;
  --d: -12s;
}

@keyframes orbit {
  from {
    transform: rotate(0deg) translateX(var(--r)) rotate(0deg);
  }

  to {
    transform: rotate(360deg) translateX(var(--r)) rotate(-360deg);
  }
}

.sat-vue {
  animation-delay: var(--d);
}

.sat-c {
  animation-delay: var(--d);
}

.sat-js {
  animation-delay: var(--d);
}

.orbit-ring {
  position: absolute;
  border: 1px dashed rgba(255, 255, 255, 0.08);
  border-radius: 99px;
}

.ring-1 {
  width: 260px;
  height: 260px;
}

.ring-2 {
  width: 200px;
  height: 200px;
  border-style: solid;
  border-color: rgba(167, 139, 250, 0.08);
}

@keyframes float {

  0%,
  100% {
    transform: translateY(0);
  }

  50% {
    transform: translateY(-6px);
  }
}

/* features */
.features {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 0.9rem;
}

.feature {
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.025), rgba(255, 255, 255, 0.012)),
    var(--bg-1);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 1.1rem 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  transition:
    border-color 200ms,
    transform 200ms;
}

.feature:hover {
  border-color: var(--accent);
  transform: translateY(-1px);
}

.feature-icon {
  width: 34px;
  height: 34px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  background: var(--accent-dim);
  color: var(--accent);
  margin-bottom: 0.25rem;
}

.feature h3 {
  font-size: 0.98em;
  font-weight: 600;
}

.feature p {
  color: var(--text-mid);
  font-size: 0.85em;
  line-height: 1.55;
}

/* stats strip */
.stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 0.75rem;
}

@media (max-width: 720px) {
  .stats {
    grid-template-columns: repeat(2, 1fr);
  }
}

.stat {
  background: rgba(255, 255, 255, 0.02);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 0.85rem 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.stat-key {
  font-size: 0.7em;
  text-transform: uppercase;
  letter-spacing: 0.14em;
  color: var(--muted);
}

.stat-val {
  font-family: var(--font-mono);
  font-size: 1em;
  color: var(--text);
}

/* callout */
.callout {
  display: flex;
  gap: 0.75rem;
  padding: 1rem 1.2rem;
  border-radius: var(--radius);
  background: linear-gradient(90deg,
      rgba(167, 139, 250, 0.07),
      rgba(96, 165, 250, 0.04));
  border: 1px solid rgba(167, 139, 250, 0.18);
}

.callout p {
  color: var(--text-mid);
  font-size: 0.88em;
  margin-top: 0.2rem;
}

.callout kbd {
  font-family: var(--font-mono);
  font-size: 0.78em;
  background: rgba(255, 255, 255, 0.07);
  border: 1px solid var(--border);
  border-radius: 4px;
  padding: 0 0.3em;
  margin: 0 0.1em;
}
</style>
