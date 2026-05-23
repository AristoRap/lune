<script setup>
import { ref } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { lune } from "../lune.js";
const { System, Notifications } = lune;

const envOut = ref("");
const screenOut = ref("");
const notifTitle = ref("Hello from Lune");
const notifBody = ref("This is a native notification.");

async function loadEnv() {
  envOut.value = JSON.stringify(await System.environment(), null, 2);
}
async function loadScreen() {
  screenOut.value = JSON.stringify(await System.screenInfo(), null, 2);
}
async function sendNotif() {
  await Notifications.notify(notifTitle.value, notifBody.value);
}
</script>

<template>
  <SectionHead eyebrow="Runtime" title="System"
    desc="Read the runtime environment, the active display, and post native notifications." />

  <div class="card-grid">
    <div class="card">
      <span class="card-label">System.environment()</span>
      <button @click="loadEnv">Get environment</button>
      <pre class="result mono">{{ envOut }}</pre>
    </div>

    <div class="card">
      <span class="card-label">System.screenInfo()</span>
      <button @click="loadScreen">Get screen info</button>
      <pre class="result mono">{{ screenOut }}</pre>
    </div>

    <div class="card">
      <span class="card-label">Notifications.notify(title, body)</span>
      <div class="form-grid">
        <input v-model="notifTitle" type="text" placeholder="Title" />
        <input v-model="notifBody" type="text" placeholder="Body" />
      </div>
      <button class="primary" @click="sendNotif">Send notification</button>
    </div>
  </div>
</template>
