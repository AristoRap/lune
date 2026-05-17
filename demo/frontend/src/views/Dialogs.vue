<script setup>
import { ref } from "vue";
import SectionHead from "../components/SectionHead.vue";
import {
  openFile,
  openFiles,
  openDir,
  saveFile,
  messageInfo,
  messageWarning,
  messageError,
  messageQuestion,
} from "../lune.js";

const pickerOut = ref("");
const dialogOut = ref("");

async function pickFile() {
  pickerOut.value = (await openFile("Select a file")) || "(cancelled)";
}
async function pickFiles() {
  const ps = await openFiles("Select files");
  pickerOut.value = ps.length ? ps.join("\n") : "(cancelled)";
}
async function pickDir() {
  pickerOut.value = (await openDir("Select a folder")) || "(cancelled)";
}
async function saveAs() {
  pickerOut.value = (await saveFile("Save as", "export.txt")) || "(cancelled)";
}

function info() {
  messageInfo("Information", "This is an info dialog from Lune.");
}
function warn() {
  messageWarning("Warning", "Something might need your attention.");
}
function err() {
  messageError("Error", "Something went wrong!");
}
async function ask() {
  const yes = await messageQuestion("Confirm", "Do you want to proceed?");
  dialogOut.value = `Answer: ${yes}`;
}
</script>

<template>
  <SectionHead
    eyebrow="OS UI"
    title="Dialogs"
    desc="Native file pickers and message dialogs, modal to the current window."
  />

  <div class="card-grid">
    <div class="card">
      <span class="card-label">File pickers</span>
      <div class="btn-row">
        <button @click="pickFile">Open file</button>
        <button @click="pickFiles">Open files</button>
        <button @click="pickDir">Open folder</button>
        <button @click="saveAs">Save file</button>
      </div>
      <pre class="result mono">{{ pickerOut }}</pre>
    </div>

    <div class="card">
      <span class="card-label">Message dialogs</span>
      <div class="btn-row">
        <button @click="info">Info</button>
        <button @click="warn">Warning</button>
        <button @click="err">Error</button>
        <button class="primary" @click="ask">Question</button>
      </div>
      <div class="result">{{ dialogOut }}</div>
    </div>
  </div>
</template>
