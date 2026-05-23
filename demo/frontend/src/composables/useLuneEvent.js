import { onBeforeUnmount } from "vue";
import { lune } from "../lune.js";

export function useLuneEvent(name, handler) {
  lune.Event.on(name, handler);
  onBeforeUnmount(() => lune.Event.off(name, handler));
}
