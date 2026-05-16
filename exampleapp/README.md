# exampleapp

A full-featured example app built with [Lune](https://github.com/aristorap/lune), demonstrating the complete Lune API — bindings, events, runtime functions, file dialogs, tray, notifications, and more.

## Running

```sh
lune dev
```

## Building

```sh
lune build
```

## What's demonstrated

- `@[Lune::Bind]` — calling Crystal methods from JavaScript
- Bidirectional event bus — `app.emit` / `app.on` (Crystal↔JS)
- Runtime functions — `quit`, `environment`, `clipboardRead/Write`, `notify`, `screenInfo`
- Window controls — `minimize`, `maximize`, `center`, `setTitle`, `setSize`
- File dialogs — `openFile`, `openFiles`, `openDir`, `saveFile`
- Message dialogs — `messageInfo`, `messageWarning`, `messageError`, `messageQuestion`
- System tray — `trayShow`, `traySetMenu`, `trayHide`
- Drag zones and file drop

## Contributors

- [Aristotelis Rapai](https://github.com/aristorap) - creator and maintainer
