<script setup>
import { ref } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { Clipboard } from "../lune.js";

const readOut = ref("");
const writeIn = ref("");
const writeOut = ref("");

const htmlOut = ref("");
const htmlIn = ref("<b>Hello</b> from <em>Lune</em>");
const htmlWriteOut = ref("");

const imageOut = ref("");
const imagePreview = ref("");

async function read() {
  readOut.value = (await Clipboard.read()) || "(empty)";
}
async function write() {
  await Clipboard.write(writeIn.value);
  writeOut.value = `Wrote ${writeIn.value.length} char(s) to clipboard.`;
}

async function readHtml() {
  htmlOut.value = (await Clipboard.readHtml()) || "(no HTML on clipboard)";
}
async function writeHtml() {
  await Clipboard.writeHtml(htmlIn.value);
  htmlWriteOut.value = "HTML written to clipboard.";
}

async function readImage() {
  const dataUrl = await Clipboard.readImage();
  if (dataUrl) {
    imagePreview.value = dataUrl;
    imageOut.value = `PNG read (${Math.round(dataUrl.length / 1024)} KB as base64).`;
  } else {
    imagePreview.value = "";
    imageOut.value = "(no image on clipboard)";
  }
}
async function writeImage() {
  if (!imagePreview.value) {
    imageOut.value = "Read an image first, then write it back.";
    return;
  }
  await Clipboard.writeImage(imagePreview.value);
  imageOut.value = "Image written back to clipboard.";
}
</script>

<template>
  <SectionHead eyebrow="Read / Write" title="Clipboard" desc="Access the system pasteboard — text, HTML, and images." />

  <div class="card-grid">
    <div class="card">
      <span class="card-label">Clipboard.read()</span>
      <button @click="read">Read text</button>
      <div class="result">{{ readOut }}</div>
    </div>

    <div class="card">
      <span class="card-label">Clipboard.write(text)</span>
      <div class="row">
        <input v-model="writeIn" type="text" placeholder="Text to copy…" />
        <button class="primary" @click="write">Write</button>
      </div>
      <div class="result">{{ writeOut }}</div>
    </div>

    <div class="card">
      <span class="card-label">Clipboard.readHtml()</span>
      <button @click="readHtml">Read HTML</button>
      <pre class="result mono">{{ htmlOut }}</pre>
    </div>

    <div class="card">
      <span class="card-label">Clipboard.writeHtml(html)</span>
      <div class="row">
        <input v-model="htmlIn" type="text" placeholder="<b>HTML</b>…" />
        <button class="primary" @click="writeHtml">Write</button>
      </div>
      <div class="result">{{ htmlWriteOut }}</div>
    </div>

    <div class="card">
      <span class="card-label">Clipboard.readImage() / Clipboard.writeImage(dataUrl)</span>
      <div class="row">
        <button @click="readImage">Read image</button>
        <button @click="writeImage" :disabled="!imagePreview">Write back</button>
      </div>
      <div class="result">{{ imageOut }}</div>
      <img v-if="imagePreview" :src="imagePreview" style="max-width:100%;margin-top:8px;border-radius:6px;" />
    </div>
  </div>
</template>
