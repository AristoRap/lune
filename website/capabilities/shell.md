# Shell

> Spawn child processes and stream their output to the frontend in real time.

|                  |                                  |
| ---------------- | -------------------------------- |
| **Config key**   | `shell`                          |
| **JS namespace** | `Shell`                          |
| **Core**         | No                               |
| **Phases**       | Bindable · Lifecycle             |
| **Hard deps**    | `stream`                         |
| **Platforms**    | macOS · Linux (Windows: planned) |

Shell lets you run commands and pipe their `stdout`/`stderr` to the browser over the WebSocket stream. Use it for build pipelines, log tailing, long-running tools, or anything that writes to standard output.

Disabling `stream` automatically disables this capability.

---

## Enabling

```yaml
capabilities:
  include:
    - shell
    - stream # required
```

Or omit `capabilities:` entirely.

---

## Spawning a process

`Shell.spawn` starts the process immediately and returns a **pid** (a random hex string). Use the pid to subscribe to output and kill the process.

```js
import { Shell } from "../lunejs/runtime/runtime.js";

const pid = await Shell.spawn("ping", ["-c", "5", "127.0.0.1"]);

Shell.listen(pid, {
  stdout: ({ line }) => console.log("out:", line),
  stderr: ({ line }) => console.error("err:", line),
  exit: ({ code }) => console.log("exited with", code),
});
```

`listen` auto-unsubscribes all three channels once the exit event fires.

---

## Collecting all output

`Shell.run` is an async binding that captures all output and resolves with `{ stdout, stderr, code }` once the process exits. Use it for short-lived commands where you want all output at once.

```js
const { stdout, stderr, code } = await Shell.run("uname", ["-a"]);
console.log(stdout); // Darwin …
```

---

## Killing a process

```js
const pid = await Shell.spawn("sleep", ["60"]);
await Shell.kill(pid); // sends SIGTERM
```

Calling `Shell.kill` on an already-exited pid is a no-op.

---

## Unsubscribing early

```js
const pid = await Shell.spawn("tail", ["-f", "/var/log/system.log"]);
Shell.listen(pid, { stdout: ({ line }) => render(line) });

// Stop receiving output but let the process keep running
Shell.unlisten(pid);
```

---

## JavaScript API

| Method     | Signature                                            | Description                       |
| ---------- | ---------------------------------------------------- | --------------------------------- |
| `spawn`    | `(command, args) → Promise<string>`                  | Start a process; returns pid      |
| `run`      | `(command, args?) → Promise<{stdout, stderr, code}>` | Spawn and collect all output      |
| `kill`     | `(pid) → Promise<void>`                              | Send SIGTERM to a running process |
| `listen`   | `(pid, opts) → void`                                 | Subscribe to output channels      |
| `unlisten` | `(pid) → void`                                       | Remove all listeners for a pid    |

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

---

## Disabling

```yaml
capabilities:
  exclude:
    - shell
```
