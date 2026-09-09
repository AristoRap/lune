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

const pid = await lune.Shell.spawn({
  command: "ping",
  args: ["-c", "5", "127.0.0.1"],
});

lune.Shell.listen(pid, {
  stdout: ({ line }) => console.log("out:", line),
  stderr: ({ line }) => console.error("err:", line),
  exit: ({ code }) => console.log("exited with", code),
});
```

`listen` returns a disposer and removes its own callbacks when it receives an exit event, even if you omit `exit`. Other subscriptions are independent.

`listen` is live-only: a process can produce output or exit before it attaches. Use `snapshot` below to recover missed output, or `run` for short commands whose complete output you need. Dispose live subscriptions when your view unmounts.

## Recovering output and completion

Every process started with `spawn` retains a bounded output history and its exit status in the backend. `snapshot({ pid, after })` atomically returns the records after a cursor, together with the current status. It works even if the process finished before `spawn` resolved or the frontend reloaded.

```js
const pid = await lune.Shell.spawn({ command: "npm", args: ["run", "build"] });
let cursor = 0;

while (true) {
  const state = await lune.Shell.snapshot({ pid, after: cursor });
  if (state.gap) console.warn("Older output was evicted");
  for (const record of state.records) {
    console.log(record.stream, record.line);
    if (record.truncated) console.warn("This line was truncated");
  }
  cursor = state.cursor;
  if (!state.running) {
    for (const error of state.errors) console.error(error);
    console.log("exited with", state.code);
    break;
  }
  await new Promise((resolve) => setTimeout(resolve, 250));
}
```

For a mounted view, stop the loop on unmount and ignore any in-flight response after disposal. Keep refreshes serialized. Store the **pid and cursor together**, and only advance the cursor after processing the returned records. Start at `0` to rebuild a cleared view; resume from a saved cursor only if you also kept the corresponding displayed output.

The recovery contract is:

- Each record has `{ seq, stream, line, truncated }`. `seq` increases across both streams for that pid; `stream` is `"stdout"` or `"stderr"`. This is backend observation order, not a guarantee of the child's chronological order between two independent pipes.
- `cursor` is the latest output sequence at snapshot time. Repeating a request returns the same retained records; independent readers maintain their own cursors. There is no server-side consume operation.
- `gap: true` means at least one record after your cursor was evicted. Process the remaining records, display the gap, and advance to the returned cursor, even if the records array is empty.
- `running: false` and a non-null `code` appear only after both output pumps finish and the child is reaped. Process the records in that same response before completion. `errors` reports output-read failures, which may make captured output incomplete. Signal termination uses code `-1`.
- Unknown, forgotten, or evicted pids reject with `shell_process_not_found`. Backend restart also invalidates old pids. Negative cursors and cursors beyond that pid's current output reject with `shell_invalid_cursor`.

Polling snapshots alone provides recovery without a replay-to-live handoff. Output arriving during a request appears in the next snapshot. Stream callbacks may be used to request an earlier refresh, but keep periodic polling to cover disconnection and missed events. Render from snapshots consistently; mixing live lines into the same view would duplicate output.

`await lune.Shell.retained()` returns all retained pids, including running processes and recent completions, so a reloaded frontend can rediscover them. `list()` continues to return only active pids. Call `await lune.Shell.forget({ pid })` to release a completed history immediately; repeating it is harmless. Forgetting a running process rejects with `shell_process_running`.

## Output limits

Configure limits in Crystal before starting processes:

```crystal
Lune.run do |opts|
  opts.shell.output_records = 4096       # records per process
  opts.shell.output_bytes = 1024 * 1024  # retained UTF-8 text bytes per process
  opts.shell.line_bytes = 64 * 1024      # input bytes kept per line
  opts.shell.completed_processes = 32   # completed histories, oldest completion first
end
```

These are the defaults; each must be positive. Invalid limits reject `spawn` with `shell_invalid_limits`. Configure them before the first spawn and keep them fixed while processes are running.

Both the record and byte limits apply. Oldest records are evicted until both limits are met; an individual record larger than the byte budget is also evicted. Exit status remains available independently of output eviction. Running histories are never evicted as a whole; the completed-history limit applies across the plugin. There is no time-based expiry. Total retained memory scales with the number of running processes plus retained completions, with additional record and pipe-buffer overhead.

Lines exceeding `line_bytes` keep their prefix and set `truncated: true`; the rest of that line is drained and discarded. This also applies to live `listen` output. Newlines are removed as before, and final text without a newline is preserved. UTF-8 characters split between reads are preserved; invalid UTF-8 and an incomplete character at a truncation boundary become U+FFFD. Replacement characters can expand the decoded text, which is then subject to `output_bytes`.

History is in memory for the lifetime of the backend. These limits apply to `spawn`; `run` still collects output without a size limit and should be used for commands with bounded output.

---

## Collecting all output

`lune.Shell.run` is an async binding that captures all output and resolves with `{ stdout, stderr, code }` once the process exits. Use it for short-lived commands where you want all output at once.

```js
const { stdout, stderr, code } = await lune.Shell.run({
  command: "uname",
  args: ["-a"],
});
console.log(stdout); // Darwin …
```

## Working directory and environment

Both `spawn` and `run` accept optional `cwd` and `env` fields:

```js
const result = await lune.Shell.run({
  command: "git",
  args: ["status", "--short"],
  cwd: "/Users/me/My Project",
  env: { GIT_OPTIONAL_LOCKS: "0", GIT_DIR: null },
});
```

- Omitting `cwd` (or passing `null`) inherits the app's working directory. Relative paths resolve from that directory. The app's directory is never changed.
- Omitting `env` (or passing `null` or `{}`) inherits the app's environment. String values override individual variables; `null` removes a variable from the child. There is no whole-environment replacement option.
- These options are per process, so concurrent commands can use different contexts without changing the app's environment.
- Executable lookup follows Crystal's process API and uses the parent process's `PATH`. Pass an absolute executable path when you need a binary from a custom location; setting the child's `PATH` controls its subsequent command lookups.

Startup errors reject with a `LuneError`: `shell_invalid_cwd` for a missing directory or a file used as `cwd`, `shell_command_not_found` for a missing executable, and `shell_spawn_failed` for other process I/O failures. On Windows, the existing `cmd /c` fallback still applies: an unknown command handled by `cmd` is reported through stderr and a nonzero exit code.

---

## Killing a process

```js
const pid = await lune.Shell.spawn({ command: "sleep", args: ["60"] });
await lune.Shell.kill({ pid }); // sends SIGTERM
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
const pid = await lune.Shell.spawn({ command: "/bin/sh", args: ["-i"] });

lune.Shell.listen(pid, {
  stdout: ({ line }) => console.log(line),
  exit: ({ code }) => console.log("exited", code),
});

await lune.Shell.write({ pid, text: "echo hello\n" });
await lune.Shell.write({ pid, text: "exit\n" });
```

`lune.Shell.close_stdin` closes the stdin pipe, which sends EOF to the process. Many programs (e.g. `sort`, `cat`, `wc`) only flush their output once stdin is closed:

```js
const pid = await lune.Shell.spawn({ command: "sort", args: [] });
await lune.Shell.write({ pid, text: "banana\n" });
await lune.Shell.write({ pid, text: "apple\n" });
lune.Shell.closeStdin({ pid }); // EOF → sort prints sorted output and exits
```

`lune.Shell.kill` also closes stdin automatically.

---

## Unsubscribing early

```js
const pid = await lune.Shell.spawn({
  command: "tail",
  args: ["-f", "/var/log/system.log"],
});
const dispose = lune.Shell.listen(pid, { stdout: ({ line }) => render(line) });

// Remove this subscription while the process keeps running.
dispose(); // safe to call more than once
```

`lune.Shell.unlisten(pid)` remains available to remove **all** subscriptions for that pid in the current JavaScript runtime. Prefer the disposer when multiple views or callers listen to the same process.

---

## JavaScript API

| Method       | Signature                                                           | Description                               |
| ------------ | ------------------------------------------------------------------- | ----------------------------------------- |
| `spawn`      | `({ command, args, cwd?, env? }) → Promise<string>`                 | Start a process; returns pid              |
| `run`        | `({ command, args, cwd?, env? }) → Promise<{stdout, stderr, code}>` | Spawn and collect all output              |
| `kill`       | `({ pid }) → Promise<void>`                                         | Send SIGTERM to a running process         |
| `list`       | `() → Promise<string[]>`                                            | List pids of all currently live processes |
| `snapshot`   | `({ pid, after? }) → Promise<Snapshot>`                             | Recover output and status after a cursor  |
| `retained`   | `() → Promise<string[]>`                                            | List running and retained completed pids  |
| `forget`     | `({ pid }) → Promise<void>`                                         | Release a completed history               |
| `write`      | `({ pid, text }) → Promise<void>`                                   | Write text to a process's stdin           |
| `closeStdin` | `({ pid }) → Promise<void>`                                         | Close stdin, sending EOF to the process   |
| `listen`     | `(pid, opts) → (() → void)`                                         | Subscribe and return a disposer           |
| `unlisten`   | `(pid) → void`                                                      | Remove all listeners for a pid            |

`listen` options:

| Key      | Type                                                   | Description                                                 |
| -------- | ------------------------------------------------------ | ----------------------------------------------------------- |
| `stdout` | `(data: { line: string; truncated: boolean }) => void` | Called per stdout line                                      |
| `stderr` | `(data: { line: string; truncated: boolean }) => void` | Called per stderr line                                      |
| `exit`   | `(data: { code: number }) => void`                     | Called on received exit after this subscription is disposed |

---

## How it works

Each spawned process gets three Stream channels keyed by its pid:

- `shell:<pid>:stdout` — one message per stdout line
- `shell:<pid>:stderr` — one message per stderr line
- `shell:<pid>:exit` — single message with `{ code }` after both pipes are drained

Crystal reads `stdout` and `stderr` in parallel async fibers, retaining each record before attempting live delivery. Both pumps signal completion even after a read failure. The waiter reaps the child and stores its exit status before attempting the live exit event. If live delivery fails, snapshots still recover the retained data and status.

---

## Notes

- **Output is line-buffered.** Each `{ line }` payload is one line. Processes that don't flush until exit produce no output until they exit or flush.
- **Shell metacharacters are not expanded.** Pass the binary as the first argument and flags as separate array elements. For pipes or globs: `spawn({ command: "/bin/sh", args: ["-c", "ls | grep foo"] })`.
- **Shutdown currently targets direct children started with `spawn`.** It does not manage descendant process trees or commands started with `run`. On POSIX it sends SIGTERM without force escalation.
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
