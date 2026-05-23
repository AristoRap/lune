<script setup>
import { computed, onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import Starfield from "./components/Starfield.vue";
import Titlebar from "./components/Titlebar.vue";
import Sidebar from "./components/Sidebar.vue";
import Statusbar from "./components/Statusbar.vue";
import Toast from "./components/Toast.vue";
import { flatNav } from "./nav.js";
import { lune } from "./lune.js";
const { System, Event } = lune;

const route = useRoute();
const router = useRouter();
const active = computed(() => route.path.slice(1) || "welcome");
const env = ref({});
const clock = ref("");
const clockPaused = ref(false);
const status = ref("Ready");

function select(id) {
  router.push("/" + id);
  status.value = `Viewing → ${flatNav.find((n) => n.id === id)?.label}`;
}

onMounted(async () => {
  try {
    env.value = await System.environment();
  } catch {
    env.value = {};
  }

  const tickH = (ts) => {
    clock.value = new Date(ts).toLocaleTimeString();
  };
  Event.on("tick", tickH);

  const pausedH = (v) => {
    clockPaused.value = v;
  };
  Event.on("clockPaused", pausedH);

  const setZoom = (z) => {
    document.body.style.zoom = String(z);
  };
  const currentZoom = () => parseFloat(document.body.style.zoom || "1");
  Event.on("zoom-in", () => setZoom(Math.round((currentZoom() + 0.1) * 10) / 10));
  Event.on("zoom-out", () => setZoom(Math.round(Math.max(0.5, currentZoom() - 0.1) * 10) / 10));
  Event.on("zoom-reset", () => setZoom(1));
});
</script>

<template>
  <Starfield />
  <Titlebar />

  <div id="shell">
    <Sidebar :active="active" :env="env" @select="select" />
    <main id="content">
      <RouterView />
    </main>
  </div>

  <Statusbar :message="status" :clock="clock" :clock-paused="clockPaused" />
  <Toast />
</template>

<style scoped>
#shell {
  flex: 1;
  display: flex;
  min-height: 0;
  position: relative;
  z-index: 1;
}

#content {
  flex: 1;
  overflow-y: auto;
  padding: 2.2rem 2.6rem 2.6rem;
  position: relative;
}
</style>

<style>
#app {
  display: flex;
  flex-direction: column;
  position: relative;
}
</style>
