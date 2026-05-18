<script setup>
import SectionHead from "../components/SectionHead.vue";
import { DragOut } from "../lune.js";

const files = [
  { label: "/etc/hosts", path: "/etc/hosts" },
  { label: "/etc/shells", path: "/etc/shells" },
];

function startDrag(path) {
  DragOut.start([path]);
}
</script>

<template>
  <SectionHead eyebrow="Native" title="Drag Out"
    desc="Initiate a native file drag from JavaScript — drag one of these chips into Finder or any other app." />

  <div class="card-grid">
    <div class="card">
      <span class="card-label">DragOut.start(paths)</span>
      <p class="card-desc">
        Hold and drag a chip out of the window to hand the file to the OS.
      </p>
      <div class="chip-row">
        <div v-for="f in files" :key="f.path" class="file-chip" draggable="false" @pointerdown="startDrag(f.path)">
          <svg class="chip-icon" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M3 2.5A1.5 1.5 0 0 1 4.5 1H9l4 4v8.5A1.5 1.5 0 0 1 11.5 15h-7A1.5 1.5 0 0 1 3 13.5v-11Z"
              stroke="currentColor" stroke-width="1.2" />
            <path d="M9 1v3.5A.5.5 0 0 0 9.5 5H13" stroke="currentColor" stroke-width="1.2" />
          </svg>
          <span class="chip-label">{{ f.label }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.chip-row {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  margin-top: 0.25rem;
}

.file-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.55em;
  padding: 0.45em 0.85em;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid var(--border);
  color: var(--text-mid);
  font-size: 0.875em;
  font-family: var(--font-mono, monospace);
  cursor: grab;
  user-select: none;
  width: fit-content;
  transition: background 150ms, border-color 150ms, color 150ms;
}

.file-chip:hover {
  background: rgba(255, 255, 255, 0.09);
  border-color: var(--accent);
  color: var(--text);
}

.file-chip:active {
  cursor: grabbing;
}

.chip-icon {
  width: 14px;
  height: 14px;
  flex-shrink: 0;
  opacity: 0.7;
}
</style>
