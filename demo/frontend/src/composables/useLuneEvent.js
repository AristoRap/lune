import { onBeforeUnmount } from "vue";
import { lune } from "../lune.js";

export function useLuneEvent(name, handler) {
  lune.Events.on(name, handler);
  onBeforeUnmount(() => lune.Events.off(name, handler));
}
