import { onBeforeUnmount } from "vue";
import { Events } from "../../lunejs/runtime/runtime.js";

export function useLuneEvent(name, handler) {
  Events.On(name, handler);
  onBeforeUnmount(() => Events.Off(name, handler));
}
