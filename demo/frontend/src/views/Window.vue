<script setup>
import { ref } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { lune } from "../lune.js";
const { Window } = lune;

const titleIn = ref("Lune Example");
const widthIn = ref(1100);
const heightIn = ref(740);

async function applyTitle() {
  await Window.setTitle(titleIn.value);
}
async function applySize() {
  await Window.setSize(parseInt(widthIn.value), parseInt(heightIn.value));
}
</script>

<template>
  <SectionHead eyebrow="Native shell" title="Window"
    desc="Drive the underlying NSWindow from JavaScript — minimise, maximise, recenter, resize, retitle." />

  <div class="card-grid">
    <div class="card">
      <span class="card-label">Controls</span>
      <div class="btn-row">
        <button @click="Window.minimize">Minimize</button>
        <button @click="Window.maximize">Maximize</button>
        <button @click="Window.center">Center</button>
      </div>
    </div>

    <div class="card">
      <span class="card-label">Window.setTitle(title)</span>
      <div class="row">
        <input v-model="titleIn" type="text" />
        <button @click="applyTitle">Set</button>
      </div>
    </div>

    <div class="card">
      <span class="card-label">Window.setSize(width, height)</span>
      <div class="row">
        <input v-model.number="widthIn" type="number" />
        <input v-model.number="heightIn" type="number" />
        <button class="primary" @click="applySize">Resize</button>
      </div>
    </div>
  </div>
</template>
