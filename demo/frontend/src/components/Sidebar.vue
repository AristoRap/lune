<script setup>
import Icon from "./Icon.vue";
import luneSrc from "../assets/images/lune.svg";
import { navGroups } from "../nav.js";

defineProps({
  active: { type: String, required: true },
  env: { type: Object, default: () => ({}) },
});

const emit = defineEmits(["select"]);

const groups = navGroups;
</script>

<template>
  <nav id="sidebar">
    <header class="brand">
      <img :src="luneSrc" class="brand-logo" alt="Lune" />
      <div class="brand-stack">
        <span class="brand-name">Lune</span>
        <span class="brand-sub">Example Showcase</span>
      </div>
    </header>

    <div class="nav-scroll">
      <div v-for="group in groups" :key="group.label" class="nav-group">
        <div class="nav-group__label">{{ group.label }}</div>
        <ul>
          <li
            v-for="item in group.items"
            :key="item.id"
            :class="{ active: item.id === active }"
            @click="emit('select', item.id)"
          >
            <Icon :name="item.icon" :size="15" />
            <span>{{ item.label }}</span>
          </li>
        </ul>
      </div>
    </div>

    <div class="sidebar-foot">
      <div class="foot-row">
        <span class="dot dot-live"></span>
        <span class="foot-key">os</span>
        <span class="foot-val">{{ env.os || "—" }}</span>
      </div>
      <div class="foot-row">
        <span class="dot dot-info"></span>
        <span class="foot-key">arch</span>
        <span class="foot-val">{{ env.arch || "—" }}</span>
      </div>
      <div class="foot-row">
        <span class="dot dot-warn"></span>
        <span class="foot-key">build</span>
        <span class="foot-val">{{ env.debug === undefined ? "—" : env.debug ? "dev" : "release" }}</span>
      </div>
    </div>
  </nav>
</template>

<style scoped>
#sidebar {
  width: var(--sidebar-w);
  background: linear-gradient(180deg, rgba(11, 13, 28, 0.72), rgba(7, 8, 15, 0.65));
  border-right: 1px solid var(--border);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  position: relative;
  z-index: 1;
}

.brand {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  padding: 0.9rem 1rem 0.85rem;
  border-bottom: 1px solid var(--border);
}
.brand-logo {
  width: 26px;
  height: 26px;
  filter: drop-shadow(0 0 10px var(--accent-glow));
}
.brand-stack {
  display: flex;
  flex-direction: column;
  line-height: 1.15;
}
.brand-name {
  font-family: var(--font-display);
  font-size: 1em;
  font-weight: 700;
  background: linear-gradient(135deg, var(--moon-1), var(--moon-2) 50%, var(--moon-3));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
.brand-sub {
  font-size: 0.7em;
  text-transform: uppercase;
  letter-spacing: 0.14em;
  color: var(--muted);
  font-weight: 600;
}

.nav-scroll {
  flex: 1;
  overflow-y: auto;
  padding: 0.9rem 0.65rem;
}

.nav-group + .nav-group {
  margin-top: 1rem;
}

.nav-group__label {
  font-size: 0.66em;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--muted);
  padding: 0.4rem 0.6rem;
}

.nav-group ul {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 1px;
}

.nav-group li {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  padding: 0.5rem 0.7rem;
  border-radius: var(--radius-sm);
  cursor: pointer;
  color: var(--text-mid);
  font-size: 0.9em;
  transition:
    color 160ms,
    background 160ms;
  user-select: none;
  position: relative;
}

.nav-group li:hover {
  color: var(--text);
  background: rgba(255, 255, 255, 0.04);
}

.nav-group li.active {
  color: var(--accent);
  background: var(--accent-dim);
  font-weight: 500;
}

.nav-group li.active::before {
  content: "";
  position: absolute;
  left: -0.65rem;
  top: 25%;
  bottom: 25%;
  width: 2px;
  border-radius: 2px;
  background: linear-gradient(180deg, var(--accent), var(--accent-2));
  box-shadow: 0 0 10px var(--accent-glow);
}

.sidebar-foot {
  border-top: 1px solid var(--border);
  padding: 0.65rem 0.85rem;
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  font-size: 0.78em;
}

.foot-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.foot-key {
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-size: 0.85em;
  width: 60px;
}
.foot-val {
  color: var(--text-mid);
  font-family: var(--font-mono);
  font-size: 0.95em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dot {
  width: 6px;
  height: 6px;
  border-radius: 99px;
  flex-shrink: 0;
}
.dot-live {
  background: var(--ok);
  box-shadow: 0 0 8px rgba(52, 211, 153, 0.6);
}
.dot-info {
  background: var(--info);
}
.dot-warn {
  background: var(--warn);
}
</style>
