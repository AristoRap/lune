# demo

A full-featured example app built with [Lune](https://github.com/aristorap/lune), demonstrating the complete Lune API — bindings, events, runtime functions, file dialogs, tray, notifications, and more.

The frontend uses the **Vue 3** template (`lune init -t vue`) with Single File Components, composables, and a celestial dark theme.

## Running

```sh
lune dev
```

## Building

```sh
lune build
```

## Frontend layout

```
frontend/
├── index.html
├── package.json          (vue + @vitejs/plugin-vue)
├── vite.config.js
└── src/
    ├── main.js           (createApp + mount)
    ├── App.vue           (titlebar + sidebar + content + statusbar)
    ├── nav.js            (sidebar groups + views)
    ├── lune.js           (single import surface for lunejs)
    ├── assets/images/    (logos)
    ├── composables/      (useLuneEvent — on/off with auto-cleanup)
    ├── components/       (Titlebar, Sidebar, Statusbar, Starfield, Icon…)
    ├── views/            (Welcome, Bindings, Event, System, …)
    └── styles/           (tokens, base, components)
```

## What's demonstrated

- `@[Lune::Bind]` — calling Crystal methods from JavaScript
- Bidirectional event bus — `app.event.emit` / `app.event.on` (Crystal↔JS)
- Runtime functions — `quit`, `environment`, `clipboardRead/Write`, `notify`, `screenInfo`
- Window controls — `minimize`, `maximize`, `center`, `setTitle`, `setSize`
- File dialogs — `openFile`, `openFiles`, `openDir`, `saveFile`
- Message dialogs — `messageInfo`, `messageWarning`, `messageError`, `messageQuestion`
- System tray — `trayShow`, `traySetMenu`, `trayHide`
- Drag zones and file drop

## Contributors

- [Aristotelis Rapai](https://github.com/aristorap) - creator and maintainer
