# FileDrop

> Accept files dragged onto the app window from the OS.

|                  |                                  |
| ---------------- | -------------------------------- |
| **Config key**   | `file_drop`                      |
| **JS namespace** | `FileDrop`                       |
| **Core**         | No                               |
| **Phases**       | WebviewInject                    |
| **Hard deps**    | `events`                         |
| **Platforms**    | macOS · Linux (Windows: planned) |

FileDrop intercepts native OS file-drop events and delivers them to JavaScript as `{ x, y, paths }` events on the event bus.

Disabling `events` automatically disables this capability.

---

## Enabling

```yaml
capabilities:
  include:
    - file_drop
    - events # required
```

Or omit `capabilities:` entirely.

---

## Basic usage

Listen for drops anywhere in the window:

```js
import { FileDrop } from "../lunejs/runtime/runtime.js";

FileDrop.on((x, y, paths) => {
  console.log("Dropped at", x, y, paths);
});

FileDrop.off(); // stop listening
```

---

## Drop zones

Mark elements as drop targets with a custom CSS property:

```crystal
Lune.run(app) do |opts|
  opts.file_drop do |fd|
    fd.zone  = "--lune-drop-target"   # CSS custom property name
    fd.value = "true"                  # expected value
  end
end
```

```css
.my-dropzone {
  --lune-drop-target: true;
}
```

When a drop zone is active, only drops that land on a matching element fire the event. The element gains a `lune-drop-target-active` class while the user is dragging over it.

---

## Crystal options

Configure in `Lune.run`:

```crystal
Lune.run(app) do |opts|
  opts.file_drop do |fd|
    fd.zone  = "--lune-drop-target"
    fd.value = "true"

    # Optional Crystal-side callback (runs before JS receives the event)
    fd.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) {
      puts "Dropped: #{paths}"
    }
  end
end
```

| Option                 | Type                                   | Description                                                     |
| ---------------------- | -------------------------------------- | --------------------------------------------------------------- |
| `zone`                 | `String`                               | CSS custom property name that marks drop targets                |
| `value`                | `String`                               | Expected value for the CSS property                             |
| `on_drop`              | `(Int32, Int32, Array(String)) -> Nil` | Crystal callback called on every drop                           |
| `disable_webview_drop` | `Bool`                                 | Prevent the WebView's own drag-drop handling (default: enabled) |

---

## JavaScript API

| Method | Signature | Description                                        |
| ------ | --------- | -------------------------------------------------- |
| `on`   | `on(cb)`  | Persistent listener; `cb` receives `(x, y, paths)` |
| `off`  | `off()`   | Remove all listeners                               |

---

## Disabling

```yaml
capabilities:
  exclude:
    - file_drop
```
