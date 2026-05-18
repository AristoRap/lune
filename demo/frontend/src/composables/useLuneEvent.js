import { onBeforeUnmount } from "vue";
import { Events } from "../../lunejs/runtime/runtime.js";

export function useLuneEvent(name, handler) {
  Events.on(name, handler);
  onBeforeUnmount(() => Events.off(name, handler));
}
