# Shell

> Spawn child processes and stream their output to the frontend in real time.

|                  |                         |
| ---------------- | ----------------------- |
| **Config key**   | `shell`                 |
| **JS namespace** | `Shell`                 |
| **Core**         | No                      |
| **Phases**       | Bindable · Lifecycle    |
| **Hard deps**    | `stream`                |
| **Platforms**    | macOS · Linux · Windows |

Shell lets you run commands and pipe their `stdout`/`stderr` to the browser over the WebSocket stream. Use it for build pipelines, log tailing, long-running tools, or anything that writes to standard output.

Disabling `stream` automatically disables this plugin.

---

## Enabling

```yaml
plugins:
  enabled:
    - shell
    - stream # required
```

Or omit `plugins:` entirely.

---

## Spawning a process

`lune.Shell.spawn` starts the process immediately and returns a **pid** (a random hex string). Use the pid to subscribe to output and kill the process.

```js
import { lune } from "../lunejs/runtime/runtime.js";

const pid = await lune.Shell.spawn("ping", ["-c", "5", "127.0.0.1"]);

lune.Shell.listen(pid, {
  stdout: ({ line }) => console.log("out:", line),
  stderr: ({ line }) => console.error("err:", line),
  exit: ({ code }) => console.log("exited with", code),
});
```

`listen` auto-unsubscribes all three channels once the exit event fires.

---

## Collecting all output

`lune.Shell.run` is an async binding that captures all output and resolves with `{ stdout, stderr, code }` once the process exits. Use it for short-lived commands where you want all output at once.

```js
const { stdout, stderr, code } = await lune.Shell.run("uname", ["-a"]);
console.log(stdout); // Darwin …
```

---

## Killing a process

```js
const pid = await lune.Shell.spawn("sleep", ["60"]);
await lune.Shell.kill(pid); // sends SIGTERM
```

Calling `lune.Shell.kill` on an already-exited pid is a no-op.

---

## Listing running processes

`lune.Shell.list` returns the pids of all processes currently alive. Use it to hydrate state in secondary windows that didn't spawn the processes.

```js
const pids = await lune.Shell.list();
// ["a1b2c3d4...", ...]

for (const pid of pids) {
  lune.Shell.listen(pid, {
    stdout: ({ line }) => console.log(line),
    exit: ({ code }) => console.log("done", code),
  });
}
```

---

## Writing to stdin

`lune.Shell.write` sends text to the standard input of a running process. Use it for interactive programs that read commands from stdin — shells, REPLs, password prompts, etc.

```js
const pid = await lune.Shell.spawn("/bin/sh", ["-i"]);

lune.Shell.listen(pid, {
  stdout: ({ line }) => console.log(line),
  exit: ({ code }) => console.log("exited", code),
});

await lune.Shell.write(pid, "echo hello\n");
await lune.Shell.write(pid, "exit\n");
```

`lune.Shell.close_stdin` closes the stdin pipe, which sends EOF to the process. Many programs (e.g. `sort`, `cat`, `wc`) only flush their output once stdin is closed:

```js
const pid = await lune.Shell.spawn("sort", []);
await lune.Shell.write(pid, "banana\n");
await lune.Shell.write(pid, "apple\n");
lune.Shell.closeStdin(pid); // EOF → sort prints sorted output and exits
```

`lune.Shell.kill` also closes stdin automatically.

---

## Unsubscribing early

```js
const pid = await lune.Shell.spawn("tail", ["-f", "/var/log/system.log"]);
lune.Shell.listen(pid, { stdout: ({ line }) => render(line) });

// Stop receiving output but let the process keep running
lune.Shell.unlisten(pid);
```

---

## JavaScript API

| Method       | Signature                                            | Description                               |
| ------------ | ---------------------------------------------------- | ----------------------------------------- |
| `spawn`      | `(command, args) → Promise<string>`                  | Start a process; returns pid              |
| `run`        | `(command, args?) → Promise<{stdout, stderr, code}>` | Spawn and collect all output              |
| `kill`       | `(pid) → Promise<void>`                              | Send SIGTERM to a running process         |
| `list`       | `() → Promise<string[]>`                             | List pids of all currently live processes |
| `write`      | `(pid, text) → Promise<void>`                        | Write text to a process's stdin           |
| `closeStdin` | `(pid) → Promise<void>`                              | Close stdin, sending EOF to the process   |
| `listen`     | `(pid, opts) → void`                                 | Subscribe to output channels              |
| `unlisten`   | `(pid) → void`                                       | Remove all listeners for a pid            |

`listen` options:

| Key      | Type                               | Description                                          |
| -------- | ---------------------------------- | ---------------------------------------------------- |
| `stdout` | `(data: { line: string }) => void` | Called per stdout line                               |
| `stderr` | `(data: { line: string }) => void` | Called per stderr line                               |
| `exit`   | `(data: { code: number }) => void` | Called once on exit; auto-unsubscribes all listeners |

---

## How it works

Each spawned process gets three Stream channels keyed by its pid:

- `shell:<pid>:stdout` — one message per stdout line
- `shell:<pid>:stderr` — one message per stderr line
- `shell:<pid>:exit` — single message with `{ code }` after both pipes are drained

Crystal reads `stdout` and `stderr` in parallel async fibers, then waits for both to close before sending the exit event — so the exit message always arrives after all output.

---

## Notes

- **Output is line-buffered.** Each `{ line }` payload is one line. Processes that don't flush until exit produce no output until they exit or flush.
- **Shell metacharacters are not expanded.** Pass the binary as the first argument and flags as separate array elements. For pipes or globs: `spawn("/bin/sh", ["-c", "ls | grep foo"])`.
- **Auto-cleanup on window close.** The `Lifecycle` shutdown hook sends SIGTERM to all running processes when the app quits.
- **Windows cmd builtins and `.cmd`/`.bat` shims work transparently.** When `CreateProcess` raises `File::NotFoundError` for a name like `echo`, `dir`, `type`, `npm.cmd`, or `yarn.cmd`, the plugin auto-retries via `cmd /c <name> …`. No manual wrapping required.

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Untested.
- **Windows** — Verified. cmd builtins (echo, dir, type, etc.) and `.cmd`/`.bat` shims (npm.cmd, yarn.cmd) work — the plugin auto-retries via `cmd /c` when direct `Process.new` raises `File::NotFoundError`.

---

## Disabling

```yaml
plugins:
  disabled:
    - shell
```
