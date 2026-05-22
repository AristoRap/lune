# WindowDrag

> Drag the OS window by mousedown on CSS-marked elements.

|                  |                                  |
| ---------------- | -------------------------------- |
| **Config key**   | `window_drag`                    |
| **JS namespace** | — (no namespace)                 |
| **Core**         | No                               |
| **Phases**       | WebviewInject                    |
| **Hard deps**    | —                                |
| **Platforms**    | macOS (Linux/Windows: planned)   |

Lets you tag DOM elements with a CSS custom property (e.g. `style="--lune-draggable: drag"`) and have mousedown on them initiate a native window drag. Essential when using a custom title bar without the OS chrome.

---

## Crystal options

```crystal
Lune.run(app) do |opts|
  opts.drag do |d|
    d.zone  = "--lune-draggable"  # CSS custom property name
    d.value = "drag"               # expected value (default — can be omitted)
  end
end
```

| Option  | Type     | Description                                          |
| ------- | -------- | ---------------------------------------------------- |
| `zone`  | `String` | CSS custom property name that marks drag handles     |
| `value` | `String` | Expected value of the property (default: `"drag"`)   |

Mark an element as a drag handle with an inline style:

```html
<div style="--lune-draggable: drag">Title bar</div>
```

> Inline style required. Detection reads `style.getPropertyValue` directly and walks up the DOM, so marking a container makes all children draggable too.

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Not implemented. Needs `_NET_WM_MOVERESIZE`; auto-filtered from the registry. Tracked in [ROADMAP.md](https://github.com/AristoRap/lune/blob/main/ROADMAP.md).
- **Windows** — Not implemented. Needs `WM_NCLBUTTONDOWN` + `HTCAPTION`; auto-filtered from the registry. Tracked in [ROADMAP.md](https://github.com/AristoRap/lune/blob/main/ROADMAP.md).

---

## Disabling

```yaml
capabilities:
  disabled:
    - window_drag
```

On Linux/Windows the platform filter handles it — the `disabled:` entry is only useful on macOS.
