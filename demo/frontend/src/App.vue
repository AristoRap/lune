<script setup>
import { computed, onMounted, ref, shallowRef } from "vue";
import Starfield from "./components/Starfield.vue";
import Titlebar from "./components/Titlebar.vue";
import Sidebar from "./components/Sidebar.vue";
import Statusbar from "./components/Statusbar.vue";
import { flatNav } from "./nav.js";
import { Lifecycle, Events } from "./lune.js";

const active = ref("welcome");
const env = ref({});
const clock = ref("");
const clockPaused = ref(false);
const status = ref("Ready");

const activeView = computed(
  () => flatNav.find((n) => n.id === active.value)?.view,
);

function select(id) {
  active.value = id;
  status.value = `Viewing → ${flatNav.find((n) => n.id === id)?.label}`;
}

onMounted(async () => {
  try {
    env.value = await Lifecycle.Environment();
  } catch {
    env.value = {};
  }

  const tickH = (ts) => {
    clock.value = new Date(ts).toLocaleTimeString();
  };
  Events.on("tick", tickH);

  const pausedH = (v) => {
    clockPaused.value = v;
  };
  Events.on("clockPaused", pausedH);
});
</script>

<template>
  <Starfield />
  <Titlebar />

  <div id="shell">
    <Sidebar :active="active" :env="env" @select="select" />
    <main id="content">
      <component :is="activeView" />
    </main>
  </div>

  <Statusbar :message="status" :clock="clock" :clock-paused="clockPaused" />
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
