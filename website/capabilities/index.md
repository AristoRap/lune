# Capabilities

Capabilities are Lune's feature modules. Each one maps to a config key in `lune.yml`, an optional JS namespace in the runtime, and a set of Crystal-side lifecycle phases.

All capabilities are **active by default**. Disable them individually with `exclude`, or whitelist specific ones with `include`:

```yaml
capabilities:
  exclude:
    - tray
    - file_watch

# or whitelist
capabilities:
  include:
    - system
    - clipboard
    - event_bus
    - stream
```

---

## Core vs standard

Two capabilities are marked **core**: `event_bus` and `stream`. They are enabled by default like every other capability — but disabling them has a cascade effect: any capability that hard-depends on them is automatically disabled too, with a warning logged at startup.

| Type     | Can be disabled? | Cascade effect                        |
| -------- | ---------------- | ------------------------------------- |
| Core     | Yes              | All hard-dependents are also disabled |
| Standard | Yes              | No cascade                            |

---

## Dependency types

| Type         | Behaviour                                                                          |
| ------------ | ---------------------------------------------------------------------------------- |
| **Hard dep** | If the dep is inactive, this capability is automatically disabled (warning logged) |
| **Soft dep** | Capability stays active but a warning is logged; feature degrades gracefully       |

---

## Lifecycle phases

| Phase             | Interface           | When it runs                                                           |
| ----------------- | ------------------- | ---------------------------------------------------------------------- |
| **Bindable**      | `install(ctx)`      | At startup — registers RPC bridge methods that become the JS namespace |
| **WebviewInject** | `init_webview(ctx)` | At startup — injects JS into the webview (and during build for stubs)  |
| **Lifecycle**     | `shutdown`          | When the window closes — releases OS resources                         |

---

## Capability matrix

| Capability                       | Config key      | JS namespace    | Core    | Phases                   | Hard deps   | Soft deps   | Platforms      |
| -------------------------------- | --------------- | --------------- | ------- | ------------------------ | ----------- | ----------- | -------------- |
| [EventBus](./event-bus)          | `event_bus`     | `Events`        | **Yes** | WebviewInject            | —           | —           | all            |
| [Stream](./stream)               | `stream`        | `Stream`        | **Yes** | WebviewInject            | —           | —           | all            |
| [Clipboard](./clipboard)         | `clipboard`     | `Clipboard`     | No      | Bindable                 | —           | —           | all            |
| [ContextMenu](./context-menu)    | `context_menu`  | `ContextMenu`   | No      | Bindable · WebviewInject | `event_bus` | —           | macOS          |
| [DeepLink](./deep-link)          | `deep_link`     | `DeepLink`      | No      | Bindable                 | `event_bus` | —           | macOS · Linux  |
| [Dialogs](./dialogs)             | `dialogs`       | `Dialogs`       | No      | Bindable                 | —           | —           | macOS · Linux  |
| [DragOut](./drag-out)            | `drag_out`      | `DragOut`       | No      | Bindable                 | —           | —           | macOS          |
| [FileDrop](./file-drop)          | `file_drop`     | `FileDrop`      | No      | WebviewInject            | `event_bus` | —           | macOS · Linux  |
| [FileWatch](./file-watch)        | `file_watch`    | `FileWatch`     | No      | Bindable · Lifecycle     | `event_bus` | —           | macOS · Linux  |
| [Filesystem](./filesystem)       | `filesystem`    | `Filesystem`    | No      | Bindable                 | —           | —           | all            |
| [Notifications](./notifications) | `notifications` | `Notifications` | No      | Bindable                 | —           | —           | macOS · Linux  |
| [Screen](./screen)               | `screen`        | `Screen`        | No      | Bindable                 | —           | —           | macOS · Linux  |
| [Shell](./shell)                 | `shell`         | `Shell`         | No      | Bindable · Lifecycle     | `stream`    | —           | macOS · Linux  |
| [System](./system)               | `system`        | `System`        | No      | Bindable                 | —           | —           | all            |
| [Tray](./tray)                   | `tray`          | `Tray`          | No      | Bindable                 | —           | `event_bus` | macOS · Linux¹ |
| [Window](./window)               | `window`        | `Window`        | No      | Bindable                 | —           | —           | macOS · Linux  |

¹ Requires XWayland on Wayland compositors.

---

## Dependency graph

```
EventBus ──► ContextMenu
         └─► DeepLink
         └─► FileDrop
         └─► FileWatch
         └─► (soft) Tray

Stream   ──► Shell
```

Disabling `event_bus` automatically disables `ContextMenu`, `DeepLink`, `FileDrop`, and `FileWatch`.
Disabling `stream` automatically disables `Shell`.
