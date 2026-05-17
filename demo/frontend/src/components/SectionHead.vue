<script setup>
defineProps({
  eyebrow: String,
  title: { type: String, required: true },
  desc: String,
});
</script>

<template>
  <header class="section-head">
    <span v-if="eyebrow" class="eyebrow">{{ eyebrow }}</span>
    <h2>{{ title }}</h2>
    <p v-if="desc" class="desc"><slot name="desc">{{ desc }}</slot></p>
    <slot />
  </header>
</template>
