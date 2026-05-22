// Sidebar navigation config — grouped sections + icons.
// Views are loaded synchronously (this is a small app and Vite bundles them anyway).

import Welcome from "./views/Welcome.vue";
import Bindings from "./views/Bindings.vue";
import Events from "./views/Events.vue";
import Stream from "./views/Stream.vue";
import System from "./views/System.vue";
import Clipboard from "./views/Clipboard.vue";
import Window from "./views/Window.vue";
import Dialogs from "./views/Dialogs.vue";
import Tray from "./views/Tray.vue";
import ContextMenu from "./views/ContextMenu.vue";
import DragOut from "./views/DragOut.vue";
import DeepLink from "./views/DeepLink.vue";
import FileWatch from "./views/FileWatch.vue";
import Hotkeys from "./views/Hotkeys.vue";
import Shell from "./views/Shell.vue";
import Kv from "./views/Kv.vue";
import Sqlite from "./views/Sqlite.vue";
import Windows from "./views/Windows.vue";
import Plugins from "./views/Plugins.vue";
import Counter from "./views/Counter.vue";

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
      { id: "stream", label: "Stream", icon: "bolt", view: Stream },
      { id: "counter", label: "Custom plugin", icon: "shield", view: Counter },
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
      { id: "filewatch", label: "File Watch", icon: "eye", view: FileWatch },
      { id: "hotkeys", label: "Hotkeys", icon: "key", view: Hotkeys },
      { id: "shell", label: "Shell", icon: "cpu", view: Shell },
      { id: "kv", label: "KV Store", icon: "database", view: Kv },
      { id: "sqlite", label: "SQLite", icon: "database", view: Sqlite },
      { id: "windows", label: "Windows", icon: "window", view: Windows },
      {
        id: "plugins",
        label: "Plugins",
        icon: "shield",
        view: Plugins,
      },
    ],
  },
];

export const flatNav = navGroups.flatMap((g) => g.items);
