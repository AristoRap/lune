# Windows verification checklist

Most Lune capabilities have shipped a Win32 implementation but **none
have been exercised on real hardware yet**: Crystal 1.20.x can't
produce a working binary on Windows MSVC ([crystal#16929](https://github.com/crystal-lang/crystal/issues/16929)),
and the fix is gated on Crystal 1.21.0 (PR
[#16933](https://github.com/crystal-lang/crystal/pull/16933) merged
to master). Until that release ships, every checklist item below
should be considered **unverified**.

Once Crystal 1.21 is out and you can produce `lune.exe`, run the demo
(`lune dev` in the `demo/` folder) on a real Windows 10/11 machine and
tick each item.

## Smoke

- [ ] `lune build` produces `build/bin/<name>.exe` and `lune run` launches it
- [ ] The window opens, navigates to the dev URL, doesn't immediately
      crash or hang
- [ ] `System.environment()` reports `{ os: "windows", arch: "x86_64" }`
- [ ] `System.openUrl("https://example.com")` opens the default browser
- [ ] `System.quit()` from the JS side closes the window cleanly

## Window basics

- [ ] `Window.setSize(800, 600)` actually resizes
- [ ] `Window.setTitle("foo")` changes the title bar text
- [ ] `Window.minimize()` and `Window.maximize()` work
- [ ] `Window.center()` recenters on the active monitor
- [ ] Frame restore on relaunch — close at a non-default position/size,
      relaunch, window comes back to that position and size

## Screen

- [ ] `Screen.info()` returns sensible `{ width, height, scale }`
- [ ] `scale` matches your Windows display setting
      (1.0 at 100%, 1.5 at 150%, etc.)

## Dialogs

- [ ] `Dialogs.openFile()` shows the Windows file picker; cancel returns `""`
- [ ] `Dialogs.openDir()` shows the Browse-Folder picker
- [ ] `Dialogs.openFiles()` allows multi-select; returns array of full paths
- [ ] `Dialogs.saveFile()` warns on overwrite, returns chosen path
- [ ] `Dialogs.info/question/warning/error` show the right icon and
      buttons; `Ok` / `Cancel` / `Yes` / `No` are returned correctly

## Clipboard

- [ ] `Clipboard.write("text")` then paste somewhere — text appears
- [ ] `Clipboard.read()` returns clipboard text
- [ ] `Clipboard.writeHtml("<b>x</b>")` then paste into Word — formatting applies
- [ ] `Clipboard.readHtml()` reads HTML copied from a browser
- [ ] `Clipboard.readImage()` / `writeImage()` — currently raise
      `NotImplementedError` (expected, scheduled for v0.12.0)

## ContextMenu

- [ ] Right-click on the demo's right-click area shows the native menu
- [ ] Selecting an item fires the `context_menu` event with the right `id`
- [ ] Dismissing (Esc or click outside) doesn't crash

## Notifications

- [ ] `Notifications.show("Title", "Body")` shows a Windows toast banner
- [ ] If toasts don't show — check Windows → Settings → System →
      Notifications & actions → "Get notifications from these senders" is
      enabled. The "Lune" AUMID is unregistered so the toast may not
      persist in Action Center; the transient banner is the success
      signal.

## Hotkeys

- [ ] `Hotkeys.register("Ctrl+Shift+K")` returns `true`; pressing the
      keys (from anywhere, including with the app unfocused) fires the
      `hotkey` event with the accelerator string
- [ ] `Hotkeys.unregister("Ctrl+Shift+K")` returns `true`; pressing
      keys after that no longer fires
- [ ] `F1`-`F12` work as single-key shortcuts (no modifier)
- [ ] `Cmd+…` and `Win+…` both map to the Windows key modifier
- [ ] Closing the app releases all hotkeys (open another app that uses
      the same combo to verify)

## DeepLink

- [ ] Register your scheme in the registry (one-time):
      `HKCU\Software\Classes\myapp\shell\open\command` default value =
      `"C:\path\to\app.exe" "%1"`. Lune doesn't auto-register schemes
      on Windows yet — track this as a v0.12.0 follow-up.
- [ ] Launch from cmd: `start myapp://hello`. The app launches, the
      `deep_link` event fires with `{ url: "myapp://hello" }`
- [ ] If the app is already running, today the URL spawns a second
      instance (no warm-start forwarding yet — Linux has the same gap)

## Known not-yet-implemented on Win32

These raise `NotImplementedError` and are tracked for v0.12.0:

- `Tray` — needs hidden HWND + Shell_NotifyIconW
- `FileWatch` — needs ReadDirectoryChangesW
- `Clipboard.readImage` / `writeImage` — needs PNG ↔ CF_DIB conversion
- `Menu.setupDefault` / `setFromOptions` — app menu bar is macOS-only
  by design (matches Linux)
- DragOut — macOS-only by design

## Reporting

If anything in the "smoke" or "window basics" sections fails, that's
a blocker. Open an issue with:

- Windows version (`winver`)
- The exact JS call you made
- The error or unexpected behaviour
- The Crystal version (`crystal -v`)
- The first ~50 lines of the Lune debug log (`%TEMP%\lune*.log` if
  it exists, or stdout/stderr if running from a terminal)
