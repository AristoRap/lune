# ContextMenuBlocker

> Block the browser's default right-click menu when `opts.disable_context_menu` is set.

|                  |                         |
| ---------------- | ----------------------- |
| **Config key**   | `context_menu_blocker`  |
| **JS namespace** | — (no namespace)        |
| **Core**         | No                      |
| **Phases**       | WebviewInject           |
| **Hard deps**    | —                       |
| **Platforms**    | macOS · Linux · Windows |

A passive capability that injects a single-line `contextmenu` listener calling `e.preventDefault()`, but only when `opts.disable_context_menu = true`. Independent of the [ContextMenu](./context-menu) capability — that one _shows_ custom native menus; this one _blocks_ the WebView's default.

---

## Crystal options

```crystal
Lune.run(app) do |opts|
  opts.disable_context_menu = true
end
```

| Option                 | Type   | Default | Description                                                                      |
| ---------------------- | ------ | ------- | -------------------------------------------------------------------------------- |
| `disable_context_menu` | `Bool` | `false` | When `true`, suppresses the browser's default context menu via `preventDefault`. |

---

## Composing with ContextMenu

The two capabilities compose: block the default browser menu with `ContextMenuBlocker`, then show your own native menu via [ContextMenu](./context-menu). When `opts.disable_context_menu = false` (the default), the browser menu shows alongside any custom one you display.

---

## Disabling

```yaml
capabilities:
  disabled:
    - context_menu_blocker
```

Disabling the cap means `opts.disable_context_menu = true` has no effect — the browser menu shows regardless.
