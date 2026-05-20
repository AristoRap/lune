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
    - events
    - stream
```

---

## Core vs standard

Two capabilities are marked **core**: `events` and `stream`. They are enabled by default like every other capability — but disabling them has a cascade effect: any capability that hard-depends on them is automatically disabled too, with a warning logged at startup.

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

| Capability                       | Config key      | JS namespace    | Core    | Phases                   | Hard deps | Soft deps | Platforms                |
| -------------------------------- | --------------- | --------------- | ------- | ------------------------ | --------- | --------- | ------------------------ |
| [Events](./events)               | `events`        | `Events`        | **Yes** | WebviewInject            | —         | —         | all                      |
| [Stream](./stream)               | `stream`        | `Stream`        | **Yes** | WebviewInject            | —         | —         | all                      |
| [Clipboard](./clipboard)         | `clipboard`     | `Clipboard`     | No      | Bindable                 | —         | —         | all (image: no Win32)    |
| [ContextMenu](./context-menu)    | `context_menu`  | `ContextMenu`   | No      | Bindable · WebviewInject | `events`  | —         | macOS (Windows/Linux: planned) |
| [DeepLink](./deep-link)          | `deep_link`     | `DeepLink`      | No      | Bindable                 | `events`  | —         | macOS · Linux · Windows² |
| [Dialogs](./dialogs)             | `dialogs`       | `Dialogs`       | No      | Bindable                 | —         | —         | all                      |
| [DragOut](./drag-out)            | `drag_out`      | `DragOut`       | No      | Bindable                 | —         | —         | macOS                    |
| [FileDrop](./file-drop)          | `file_drop`     | `FileDrop`      | No      | WebviewInject            | `events`  | —         | macOS · Linux            |
| [FileWatch](./file-watch)        | `file_watch`    | `FileWatch`     | No      | Bindable · Lifecycle     | `events`  | —         | macOS · Linux            |
| [Filesystem](./filesystem)       | `filesystem`    | `Filesystem`    | No      | Bindable                 | —         | —         | all                      |
| [Hotkeys](./hotkeys)             | `hotkeys`       | `Hotkeys`       | No      | Bindable                 | —         | `events`  | macOS · Linux · Windows  |
| [Notifications](./notifications) | `notifications` | `Notifications` | No      | Bindable                 | —         | —         | all                      |
| [Screen](./screen)               | `screen`        | `Screen`        | No      | Bindable                 | —         | —         | all                      |
| [Kv](./kv)                       | `kv`            | `Kv`            | No      | Bindable · Lifecycle     | —         | —         | all                      |
| [Shell](./shell)                 | `shell`         | `Shell`         | No      | Bindable · Lifecycle     | `stream`  | —         | macOS · Linux · Windows³ |
| [Sqlite](./sqlite)               | `sqlite`        | `Sqlite`        | No      | Bindable · Lifecycle     | —         | —         | all                      |
| [System](./system)               | `system`        | `System`        | No      | Bindable                 | —         | —         | all                      |
| [Tray](./tray)                   | `tray`          | `Tray`          | No      | Bindable                 | —         | `events`  | macOS · Linux¹           |
| [Window](./window)               | `window`        | `Window`        | No      | Bindable                 | —         | —         | all (chrome opts macOS)  |
| [Windows](./windows)             | `windows`       | `Windows`       | No      | Bindable · Lifecycle     | —         | —         | all                      |

¹ Requires XWayland on Wayland compositors.
² Linux/Windows: cold-start (ARGV) only — no warm-start forwarding yet.
³ Windows: cmd builtins (echo, dir, type, etc.) fail; wrap with cmd /c <builtin> ….  Real executables work normally — see [Shell › Notes](./shell#notes).

> **Windows runtime caveat.** Every "Windows" entry above is in tree; many are now verified on real hardware. Until Crystal 1.21 ships, building a runnable binary requires the one-line stdlib patch documented in [WINDOWS_SETUP.md](https://github.com/AristoRap/lune/blob/main/WINDOWS_SETUP.md) ([crystal#16929](https://github.com/crystal-lang/crystal/issues/16929), fix in master via [crystal#16933](https://github.com/crystal-lang/crystal/pull/16933)). With the patch applied, the runtime works end-to-end. See [WINDOWS_SETUP.md](https://github.com/AristoRap/lune/blob/main/WINDOWS_SETUP.md) and the [Windows verification checklist](../guide/windows-checklist) for full status.

---

## Dependency graph

```
Events ──► ContextMenu
         └─► DeepLink
         └─► FileDrop
         └─► FileWatch
         └─► (soft) Tray

Stream   ──► Shell
```

Disabling `events` automatically disables `ContextMenu`, `DeepLink`, `FileDrop`, and `FileWatch`.
Disabling `stream` automatically disables `Shell`.
