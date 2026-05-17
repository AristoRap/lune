<script setup>
// Drag-zone only — the native macOS title bar renders on top (full_size_content),
// so we don't draw any chrome here. Just provides height + drag.
</script>

<template>
  <div id="titlebar" style="--lune-draggable: drag"></div>
</template>

<style scoped>
#titlebar {
  height: var(--titlebar-h);
  background: linear-gradient(
    180deg,
    rgba(11, 13, 28, 0.85),
    rgba(11, 13, 28, 0.45)
  );
  border-bottom: 1px solid var(--border);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
  flex-shrink: 0;
  position: relative;
  z-index: 2;
}
</style>
