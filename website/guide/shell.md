# Shell

The `shell` capability lets you spawn child processes and stream their `stdout` and `stderr` to the frontend in real time over the WebSocket stream. Use it for long-running commands, build pipelines, log tailing, or any tool that writes to standard output.

Hard-depends on `stream` — disabling `stream` automatically disables `shell`.

---

## Enabling

Shell is off by default. Add it to your `lune.yml`:

```yaml
capabilities:
  include:
    - shell
    - stream   # required — shell is disabled automatically if stream is absent
```

Or omit `capabilities:` entirely to enable everything.

---

## Spawning a process

`Shell.spawn(command, args)` starts the process and immediately returns a **process ID** (a random hex string). Use the pid to subscribe to output and to kill the process.

```js
import { Shell } from "../lunejs/runtime/runtime.js";

const pid = await Shell.spawn("ping", ["-c", "5", "127.0.0.1"]);

Shell.listen(pid, {
  stdout: ({ line }) => console.log("out:", line),
  stderr: ({ line }) => console.error("err:", line),
  exit:   ({ code }) => console.log("exited with", code),
});
```

`listen` auto-unsubscribes all three channels once the exit event fires — no manual cleanup needed unless you call `unlisten` early.

---

## Collecting output on exit

`Shell.run(command, args?)` is a Crystal-side async binding that captures all output and resolves with `{ stdout, stderr, code }` once the process exits. Because it collects output inside Crystal, it has no Stream ordering constraints and works correctly for instant commands.

```js
const { stdout, stderr, code } = await Shell.run("uname", ["-a"]);
console.log(stdout);  // Darwin …
```

Use `Shell.run` for short-lived commands where you want all output at once. Use `Shell.spawn` + `Shell.listen` when you need to display output as it arrives.

---

## Killing a process

```js
const pid = await Shell.spawn("sleep", ["60"]);
await Shell.kill(pid);   // sends SIGTERM
```

Calling `Shell.kill` on an already-exited pid is a no-op.

---

## Unsubscribing early

```js
const pid = await Shell.spawn("tail", ["-f", "/var/log/system.log"]);
Shell.listen(pid, { stdout: ({ line }) => render(line) });

// Later — stop receiving but let the process keep running
Shell.unlisten(pid);
```

`unlisten` removes all Stream listeners for the pid's `stdout`, `stderr`, and `exit` channels but does not terminate the process.

---

## JavaScript API

| Method | Signature | Description |
|--------|-----------|-------------|
| `spawn` | `(command: string, args: string[]) → Promise<string>` | Spawn a process; returns the pid |
| `kill` | `(pid: string) → Promise<void>` | Send SIGTERM to a running process |
| `listen` | `(pid, opts) → void` | Subscribe to stdout/stderr/exit for a pid |
| `unlisten` | `(pid: string) → void` | Remove all listeners for a pid |
| `run` | `(command: string, args?: string[]) → Promise<{stdout, stderr, code}>` | Spawn and collect all output |

`listen` options:

| Key | Type | Description |
|-----|------|-------------|
| `stdout` | `(data: { line: string }) => void` | Called for each stdout line |
| `stderr` | `(data: { line: string }) => void` | Called for each stderr line |
| `exit` | `(data: { code: number }) => void` | Called once when the process exits; auto-unsubscribes all listeners |

---

## How it works

Each spawned process gets three Stream channels keyed by its pid:

- `shell:<pid>:stdout` — one message per stdout line
- `shell:<pid>:stderr` — one message per stderr line
- `shell:<pid>:exit` — single message with `{ code }` after both pipes are drained

Crystal reads `stdout` and `stderr` in parallel async fibers, then waits for both to close before sending the exit event — so the exit message always arrives after all output.

---

## Notes

- **Output is line-buffered.** Each `{ line }` payload is one line (newline stripped by `IO#gets`). Processes that don't flush until exit (e.g. some C programs) will produce no output until they exit or flush.
- **Shell metacharacters are not expanded.** `spawn("ls -la", [])` will fail — pass the binary as the first argument and flags as separate array elements. For shell features like pipes or globs, use `spawn("/bin/sh", ["-c", "ls | grep foo"])`.
- **Auto-cleanup on window close.** The `Lifecycle` shutdown hook sends SIGTERM to all running processes when the app quits.
