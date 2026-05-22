# Hotkeys

System-wide keyboard shortcuts that fire even when the app window is not focused.

## Enabling

`hotkeys` is included in the default plugin set. To be explicit:

```yaml
plugins:
  enabled:
    - hotkeys
```

Soft-depends on `events` — hotkey events are delivered via the event bus. If `events` is excluded, hotkey events are silently dropped.

## Registering shortcuts

```js
import { lune } from "../lunejs/runtime/runtime.js";

// Register on page load
await lune.Hotkeys.register("Ctrl+Shift+K");
await lune.Hotkeys.register("Ctrl+Shift+P");

// Unregister when no longer needed
await lune.Hotkeys.unregister("Ctrl+Shift+K");
```

Shortcuts are released automatically when the app quits. You do not need to unregister them manually on exit.

## Listening for triggers

Hotkey events arrive via the event bus under the `"hotkey"` event name. `data.key` is the accelerator string exactly as registered:

```js
lune.Events.on("hotkey", (data) => {
  switch (data.key) {
    case "Ctrl+Shift+K":
      openSearch();
      break;
    case "Ctrl+Shift+P":
      openCommandPalette();
      break;
  }
});
```

Or use the `lune.Hotkeys.on` convenience wrapper (identical to `lune.Events.on("hotkey", ...)`):

```js
lune.Hotkeys.on((data) => {
  console.log("pressed:", data.key);
});
```

## Accelerator format

Accelerators are `+`-separated modifier and key names, case-insensitive:

| Modifier | Aliases   |
| -------- | --------- |
| `Ctrl`   | `Control` |
| `Cmd`    | `Command` |
| `Shift`  | —         |
| `Alt`    | `Option`  |

Key names: `A`–`Z`, `0`–`9`, `F1`–`F12`, `Space`, `Return`, `Enter`, `Tab`, `Backspace`, `Delete`, `Escape`, `Left`, `Right`, `Up`, `Down`, `Home`, `End`, `PageUp`, `PageDown`, `Minus`, `Equal`, and common punctuation (`[`, `]`, `;`, `'`, `` ` ``, `,`, `.`, `/`, `\`).

```js
await lune.Hotkeys.register("Ctrl+K"); // single modifier
await lune.Hotkeys.register("Cmd+Shift+P"); // macOS
await lune.Hotkeys.register("Ctrl+Shift+F5"); // modifier + function key
await lune.Hotkeys.register("Alt+Left"); // modifier + arrow
```

## Full example

```js
import { lune } from "../lunejs/runtime/runtime.js";

async function setupHotkeys() {
  await lune.Hotkeys.register("Ctrl+Shift+K");
  await lune.Hotkeys.register("Ctrl+Shift+N");

  lune.Hotkeys.on((data) => {
    if (data.key === "Ctrl+Shift+K") toggleSearch();
    if (data.key === "Ctrl+Shift+N") createNew();
  });
}
```

## Notes

- Shortcuts that conflict with another app's system-wide hotkeys (e.g. OS shortcuts) will silently fail to register. A `warn` log entry is emitted when registration fails.
- Registered hotkeys are global to the session — they fire regardless of which app has focus.

## Platform notes

- **macOS** — Verified. Uses Carbon `RegisterEventHotKey`; no Accessibility permission required.
- **Linux** — Untested. Uses `XGrabKey` on the root window via a background X11 connection.
- **Windows** — Verified. Uses `RegisterHotKey` on a dedicated WM_HOTKEY pump thread; `Cmd+…` and `Win+…` both map to the Windows key modifier.
