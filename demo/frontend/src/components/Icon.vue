<script setup>
import { computed } from "vue";

const props = defineProps({
  name: { type: String, required: true },
  size: { type: [Number, String], default: 16 },
});

const sizePx = computed(() =>
  typeof props.size === "number" ? `${props.size}px` : props.size,
);

// All icons sit on a 24×24 grid, stroke only — they recolor with currentColor.
const paths = {
  moon: "M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z",
  code: "M8 7l-5 5 5 5 M16 7l5 5-5 5 M14 4l-4 16",
  bolt: "M13 2L4 14h7l-1 8 9-12h-7l1-8z",
  cpu: "M9 3v3 M15 3v3 M9 18v3 M15 18v3 M3 9h3 M3 15h3 M18 9h3 M18 15h3 M6 6h12v12H6z M9 9h6v6H9z",
  clipboard:
    "M9 4h6a1 1 0 0 1 1 1v1h2v15H6V6h2V5a1 1 0 0 1 1-1z M9 4v2h6V4",
  window:
    "M3 5h18v14H3z M3 9h18 M6 7h.01 M9 7h.01",
  dialog:
    "M4 5h16v10H8l-4 4z M8 9h8 M8 12h5",
  tray: "M4 4h16v10H4z M4 14l3 5h10l3-5 M9 8h6",
  shield: "M12 2l8 4v6c0 5-4 9-8 10C8 21 4 17 4 12V6l8-4z",
  drag: "M9 3v18 M15 3v18 M3 9h18 M3 15h18",
  link: "M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71 M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71",
};

const d = computed(() => paths[props.name] || paths.moon);
</script>

<template>
  <svg class="icon" :width="sizePx" :height="sizePx" viewBox="0 0 24 24" fill="none" stroke="currentColor"
    stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
    <path :d="d" />
  </svg>
</template>

<style scoped>
.icon {
  flex-shrink: 0;
  display: block;
}
</style>
