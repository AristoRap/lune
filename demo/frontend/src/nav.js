// Sidebar navigation config — grouped sections + icons.
// Views are loaded synchronously (this is a small app and Vite bundles them anyway).

import Welcome from "./views/Welcome.vue";
import Bindings from "./views/Bindings.vue";
import Events from "./views/Events.vue";
import System from "./views/System.vue";
import Clipboard from "./views/Clipboard.vue";
import Window from "./views/Window.vue";
import Dialogs from "./views/Dialogs.vue";
import Tray from "./views/Tray.vue";
import ContextMenu from "./views/ContextMenu.vue";
import DragOut from "./views/DragOut.vue";
import DeepLink from "./views/DeepLink.vue";
import Capabilities from "./views/Capabilities.vue";

export const navGroups = [
  {
    label: "Overview",
    items: [{ id: "welcome", label: "Welcome", icon: "moon", view: Welcome }],
  },
  {
    label: "Bridge",
    items: [
      { id: "bindings", label: "Bindings", icon: "code", view: Bindings },
      { id: "events", label: "Events", icon: "bolt", view: Events },
    ],
  },
  {
    label: "Native",
    items: [
      { id: "system", label: "System", icon: "cpu", view: System },
      {
        id: "clipboard",
        label: "Clipboard",
        icon: "clipboard",
        view: Clipboard,
      },
      { id: "window", label: "Window", icon: "window", view: Window },
      { id: "dialogs", label: "Dialogs", icon: "dialog", view: Dialogs },
      { id: "tray", label: "Tray", icon: "tray", view: Tray },
      {
        id: "contextmenu",
        label: "Context Menu",
        icon: "menu",
        view: ContextMenu,
      },
      { id: "dragout", label: "Drag Out", icon: "drag", view: DragOut },
      { id: "deeplink", label: "Deep Links", icon: "link", view: DeepLink },
      {
        id: "capabilities",
        label: "Capabilities",
        icon: "shield",
        view: Capabilities,
      },
    ],
  },
];

export const flatNav = navGroups.flatMap((g) => g.items);
