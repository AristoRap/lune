# Navigation

> Drive `opts.on_navigate` from every client-side URL change, including SPA-router transitions.

|                  |                         |
| ---------------- | ----------------------- |
| **Config key**   | `navigation`            |
| **JS namespace** | — (no namespace)        |
| **Core**         | No                      |
| **Phases**       | WebviewInject           |
| **Hard deps**    | —                       |
| **Platforms**    | macOS · Linux · Windows |

Injects a tiny shim that listens for `popstate` and `hashchange` and patches `history.pushState` / `replaceState` so SPA-router transitions also fire. The shim is only installed when `opts.on_navigate` is set — without a callback, the capability does nothing at runtime.

---

## Crystal options

```crystal
Lune.run(app) do |opts|
  opts.on_navigate = ->(url : String) {
    Lune.logger.info { "navigated to #{url}" }
  }
end
```

| Option        | Type               | Description                                                        |
| ------------- | ------------------ | ------------------------------------------------------------------ |
| `on_navigate` | `(String -> Nil)?` | Called on every URL change with the new `location.href`. Optional. |

---

## What fires the callback

The shim consolidates four sources into one callback:

| Trigger                           | Example                           |
| --------------------------------- | --------------------------------- |
| `popstate` (browser back/forward) | History buttons, `history.back()` |
| `hashchange`                      | `location.hash = "#foo"`          |
| `history.pushState`               | React Router, vue-router HTML5    |
| `history.replaceState`            | Same — `router.replace(...)`      |

Same-URL fires are deduped — vue-router hash mode (which calls `pushState` _and_ mutates `location.hash` on every click) only triggers the callback once per transition.

---

## Error handling

Exceptions raised inside `on_navigate` are caught and logged (`error` + `debug` with stacktrace) — navigation continues to fire for subsequent URL changes. Your callback can `raise` without breaking further events.

---

## Disabling

```yaml
capabilities:
  disabled:
    - navigation
```

Disable if you have your own URL-change router on the JS side and don't want the Crystal callback to fire (the `opts.on_navigate` field becomes a no-op).
