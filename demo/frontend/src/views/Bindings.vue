<script setup>
import { ref } from "vue";
import SectionHead from "../components/SectionHead.vue";
import { api, LuneError } from "../lune.js";

const greetIn = ref("");
const greetOut = ref("");
const revIn = ref("");
const revOut = ref("");
const fiIn = ref("");
const fiOut = ref("");
const errCode = ref("validation_error");
const errOut = ref(null);

async function callGreet() {
  greetOut.value = await api.Demo.greet(greetIn.value);
}

async function callReverse() {
  revOut.value = await api.Demo.reverse(revIn.value);
}

async function callFileInfo() {
  const raw = await api.Demo.fileInfo(fiIn.value);
  try {
    fiOut.value = JSON.stringify(JSON.parse(raw), null, 2);
  } catch {
    fiOut.value = raw;
  }
}

async function callFailWith() {
  errOut.value = null;
  try {
    await api.Demo.failWith(errCode.value);
  } catch (err) {
    errOut.value = {
      isLuneError: err instanceof LuneError,
      name: err.name,
      code: err.code,
      message: err.message,
    };
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

    <div class="card">
      <span class="card-label">fail_with(code) → LuneError</span>
      <div class="row">
        <input v-model="errCode" type="text" placeholder="error_code" />
        <button @click="callFailWith">Trigger Error</button>
      </div>
      <pre v-if="errOut" class="result mono">{{ JSON.stringify(errOut, null, 2) }}</pre>
    </div>
  </div>
</template>
