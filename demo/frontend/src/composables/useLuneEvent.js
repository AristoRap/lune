import { onBeforeUnmount } from "vue";
import { on, off } from "../../lunejs/runtime/runtime.js";

export function useLuneEvent(name, handler) {
  on(name, handler);
  onBeforeUnmount(() => off(name, handler));
}
