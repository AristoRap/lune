<script setup>
import { ref } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { clipboardRead, clipboardWrite } from "../lune.js";

const readOut = ref("");
const writeIn = ref("");
const writeOut = ref("");

async function read() {
  readOut.value = (await clipboardRead()) || "(empty)";
}
async function write() {
  await clipboardWrite(writeIn.value);
  writeOut.value = `Wrote ${writeIn.value.length} char(s) to clipboard.`;
}
</script>

<template>
  <SectionHead
    eyebrow="Read / Write"
    title="Clipboard"
    desc="Access the system pasteboard — useful for copy-friendly outputs or pulling text from elsewhere."
  />

  <div class="card-grid">
    <div class="card">
      <span class="card-label">clipboardRead()</span>
      <button @click="read">Read clipboard</button>
      <div class="result">{{ readOut }}</div>
    </div>

    <div class="card">
      <span class="card-label">clipboardWrite(text)</span>
      <div class="row">
        <input v-model="writeIn" type="text" placeholder="Text to copy…" />
        <button class="primary" @click="write">Write</button>
      </div>
      <div class="result">{{ writeOut }}</div>
    </div>
  </div>
</template>
