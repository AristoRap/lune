<script setup>
import { ref } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { trayShow, trayHide, traySetMenu, quit } from "../lune.js";
import { useLuneEvent } from "../composables/useLuneEvent.js";

const log = ref([]);
const activeMenu = ref(null);
const visible = ref(false);

useLuneEvent("trayEvent", (id) => {
  log.value.unshift(`trayEvent: ${JSON.stringify(id)}`);
  if (id === "quit") quit();
});

async function toggle() {
  if (visible.value) {
    await trayHide();
    visible.value = false;
  } else {
    await trayShow("");
    visible.value = true;
  }
}

function setMenuA() {
  traySetMenu([
    { id: "open", label: "Open" },
    { id: "---", label: "" },
    { id: "quit", label: "Quit" },
  ]);
  activeMenu.value = "a";
}
function setMenuB() {
  traySetMenu([
    { id: "pause", label: "Pause" },
    { id: "resume", label: "Resume" },
    { id: "---", label: "" },
    { id: "quit", label: "Quit" },
  ]);
  activeMenu.value = "b";
}
function clearMenu() {
  traySetMenu([]);
  activeMenu.value = null;
}
</script>

<template>
  <SectionHead
    eyebrow="Status bar"
    title="System Tray"
    desc="Show an icon in the status bar with an optional context menu. Click and menu events flow back through the event bus."
  />

  <div class="card-grid">
    <div class="card">
      <span class="card-label">Icon</span>
      <div class="btn-row align-center">
        <button
          class="toggle"
          :class="{ on: visible }"
          role="switch"
          :aria-checked="visible"
          @click="toggle"
        >
          <span class="toggle-track"><span class="toggle-thumb"></span></span>
          <span class="toggle-label">
            {{ visible ? "Visible in status bar" : "Hidden" }}
          </span>
        </button>
      </div>
    </div>

    <div class="card">
      <span class="card-label">Context menu</span>
      <div class="btn-row">
        <button :class="{ primary: activeMenu === 'a' }" @click="setMenuA">
          Menu A (Open · Quit)
        </button>
        <button :class="{ primary: activeMenu === 'b' }" @click="setMenuB">
          Menu B (Pause · Resume · Quit)
        </button>
        <button @click="clearMenu">Clear menu</button>
      </div>
    </div>

    <div class="card">
      <span class="card-label">Event log</span>
      <div class="log">
        <div v-if="!log.length" class="log-empty">Tray events appear here…</div>
        <div v-for="(entry, i) in log" :key="i" class="log-entry">{{ entry }}</div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.align-center {
  align-items: center;
}

.toggle {
  display: inline-flex;
  align-items: center;
  gap: 0.65em;
  background: transparent;
  border: none;
  padding: 0;
  color: var(--text-mid);
  font-size: 0.92em;
  cursor: pointer;
}
.toggle:hover {
  background: transparent;
  border-color: transparent;
}
.toggle:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 4px;
  border-radius: 99px;
}

.toggle-track {
  width: 38px;
  height: 22px;
  border-radius: 99px;
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid var(--border);
  position: relative;
  transition: background 180ms, border-color 180ms;
  flex-shrink: 0;
}
.toggle-thumb {
  position: absolute;
  top: 2px;
  left: 2px;
  width: 16px;
  height: 16px;
  border-radius: 99px;
  background: var(--text-mid);
  transition: transform 180ms, background 180ms;
}
.toggle.on .toggle-track {
  background: linear-gradient(135deg, var(--accent), var(--accent-2));
  border-color: transparent;
  box-shadow: 0 0 14px var(--accent-glow);
}
.toggle.on .toggle-thumb {
  background: #fff;
  transform: translateX(16px);
}
.toggle.on .toggle-label {
  color: var(--text);
}
</style>
