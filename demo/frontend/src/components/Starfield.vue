<script setup>
// Deterministic-feeling but cheap: pure CSS layered radial gradients
// twinkle via two stacked layers drifting at different speeds.
</script>

<template>
  <div class="starfield" aria-hidden="true">
    <div class="layer layer-a"></div>
    <div class="layer layer-b"></div>
    <div class="aurora"></div>
  </div>
</template>

<style scoped>
.starfield {
  position: fixed;
  inset: 0;
  z-index: 0;
  pointer-events: none;
  overflow: hidden;
}

.layer {
  position: absolute;
  inset: -10%;
  background-repeat: repeat;
  opacity: 0.55;
}

.layer-a {
  background-image:
    radial-gradient(1px 1px at 20px 30px, rgba(255, 255, 255, 0.55), transparent 60%),
    radial-gradient(1px 1px at 90px 120px, rgba(199, 199, 255, 0.6), transparent 60%),
    radial-gradient(1.4px 1.4px at 160px 60px, rgba(255, 255, 255, 0.7), transparent 60%),
    radial-gradient(1px 1px at 230px 200px, rgba(167, 139, 250, 0.6), transparent 60%),
    radial-gradient(1px 1px at 300px 100px, rgba(255, 255, 255, 0.5), transparent 60%);
  background-size: 340px 240px;
  animation: drift-a 120s linear infinite;
}

.layer-b {
  background-image:
    radial-gradient(1.6px 1.6px at 40px 80px, rgba(255, 255, 255, 0.45), transparent 60%),
    radial-gradient(1px 1px at 170px 160px, rgba(124, 108, 255, 0.65), transparent 60%),
    radial-gradient(1px 1px at 260px 40px, rgba(255, 255, 255, 0.4), transparent 60%);
  background-size: 420px 320px;
  opacity: 0.35;
  animation: drift-b 200s linear infinite;
}

.aurora {
  position: absolute;
  top: -20%;
  left: -10%;
  right: -10%;
  height: 60%;
  background: radial-gradient(
      60% 80% at 30% 30%,
      rgba(124, 108, 255, 0.16),
      transparent 70%
    ),
    radial-gradient(50% 70% at 80% 40%, rgba(96, 165, 250, 0.08), transparent 70%);
  filter: blur(20px);
  animation: pulse 14s ease-in-out infinite alternate;
}

@keyframes drift-a {
  from {
    transform: translate3d(0, 0, 0);
  }
  to {
    transform: translate3d(-340px, -240px, 0);
  }
}

@keyframes drift-b {
  from {
    transform: translate3d(0, 0, 0);
  }
  to {
    transform: translate3d(-420px, 320px, 0);
  }
}

@keyframes pulse {
  from {
    opacity: 0.7;
  }
  to {
    opacity: 1;
  }
}
</style>
