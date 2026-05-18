<script setup>
import { ref } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { Window } from "../lune.js";

const titleIn = ref("Lune Example");
const widthIn = ref(1100);
const heightIn = ref(740);

async function applyTitle() {
  await Window.SetTitle(titleIn.value);
}
async function applySize() {
  await Window.SetSize(parseInt(widthIn.value), parseInt(heightIn.value));
}
</script>

<template>
  <SectionHead
    eyebrow="Native shell"
    title="Window"
    desc="Drive the underlying NSWindow from JavaScript — minimise, maximise, recenter, resize, retitle."
  />

  <div class="card-grid">
    <div class="card">
      <span class="card-label">Controls</span>
      <div class="btn-row">
        <button @click="Window.Minimize">Minimize</button>
        <button @click="Window.Maximize">Maximize</button>
        <button @click="Window.Center">Center</button>
      </div>
    </div>

    <div class="card">
      <span class="card-label">Window.SetTitle(title)</span>
      <div class="row">
        <input v-model="titleIn" type="text" />
        <button @click="applyTitle">Set</button>
      </div>
    </div>

    <div class="card">
      <span class="card-label">Window.SetSize(width, height)</span>
      <div class="row">
        <input v-model.number="widthIn" type="number" />
        <input v-model.number="heightIn" type="number" />
        <button class="primary" @click="applySize">Resize</button>
      </div>
    </div>
  </div>
</template>
