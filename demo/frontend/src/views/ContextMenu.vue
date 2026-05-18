<script setup>
import { ref, onUnmounted } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { ContextMenuBridge } from "../lune.js";

const active = ref(false);
const lastId = ref("");

const items = [
  { id: "copy", label: "Copy" },
  { id: "paste", label: "Paste" },
  { separator: true },
  { id: "delete", label: "Delete", enabled: false },
  { id: "inspect", label: "Inspect" },
];

ContextMenuBridge.onContextMenu((id) => {
  lastId.value = id;
});

function toggle() {
  if (active.value) {
    ContextMenuBridge.clearContextMenu();
    active.value = false;
  } else {
    ContextMenuBridge.setContextMenu(items);
    active.value = true;
  }
}

onUnmounted(() => ContextMenuBridge.clearContextMenu());
</script>

<template>
  <SectionHead eyebrow="Native" title="Context Menu"
    desc="Show a native right-click context menu driven from JavaScript." />

  <div class="card-grid">
    <div class="card">
      <span class="card-label">ContextMenuBridge.setContextMenu(items)</span>
      <div class="btn-row align-center">
        <button class="toggle" :class="{ on: active }" role="switch" :aria-checked="active" @click="toggle">
          <span class="toggle-track"><span class="toggle-thumb"></span></span>
          <span class="toggle-label">
            {{ active ? "Active — right-click anywhere" : "Inactive" }}
          </span>
        </button>
      </div>
    </div>

    <div class="card">
      <span class="card-label">ContextMenuBridge.onContextMenu(cb)</span>
      <p class="card-desc">Last selected item id.</p>
      <pre class="result mono">{{ lastId || "(none yet)" }}</pre>
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
