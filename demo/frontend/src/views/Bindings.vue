<script setup>
import { ref } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { api } from "../lune.js";

const greetIn = ref("");
const greetOut = ref("");
const revIn = ref("");
const revOut = ref("");
const fiIn = ref("");
const fiOut = ref("");

async function callGreet() {
  greetOut.value = await api.Demo.Greet(greetIn.value);
}

async function callReverse() {
  revOut.value = await api.Demo.Reverse(revIn.value);
}

async function callFileInfo() {
  const raw = await api.Demo.FileInfo(fiIn.value);
  try {
    fiOut.value = JSON.stringify(JSON.parse(raw), null, 2);
  } catch {
    fiOut.value = raw;
  }
}
</script>

<template>
  <SectionHead eyebrow="Crystal → JavaScript" title="Bindings">
    <template #desc>
      Annotate any Crystal method with <code>@[Lune::Bind]</code> and Lune
      generates a JavaScript shim. Calls always return a
      <code>Promise</code>.
    </template>
  </SectionHead>

  <div class="card-grid">
    <div class="card">
      <span class="card-label">greet(name)</span>
      <div class="row">
        <input v-model="greetIn" type="text" placeholder="Your name…" />
        <button class="primary" @click="callGreet">Call</button>
      </div>
      <div class="result">{{ greetOut }}</div>
    </div>

    <div class="card">
      <span class="card-label">reverse(text)</span>
      <div class="row">
        <input v-model="revIn" type="text" placeholder="hello world" />
        <button @click="callReverse">Call</button>
      </div>
      <div class="result">{{ revOut }}</div>
    </div>

    <div class="card">
      <span class="card-label">file_info(path)</span>
      <div class="row">
        <input v-model="fiIn" type="text" placeholder="/path/to/file" />
        <button @click="callFileInfo">Call</button>
      </div>
      <pre class="result mono">{{ fiOut }}</pre>
    </div>
  </div>
</template>
