import assert from "node:assert/strict";
import vm from "node:vm";
import { readFileSync } from "node:fs";
const { helpers, marker, runtime } = JSON.parse(readFileSync(0, "utf8"));
let handlers = {};
const bridge = {
  stOn(name, cb) {
    (handlers[name] ||= []).push(cb);
  },
  stOff(name, cb) {
    if (!cb) delete handlers[name];
    else if (handlers[name])
      handlers[name] = handlers[name].filter((f) => f !== cb);
  },
};
const shell = vm.runInNewContext("({" + helpers + "})", {
  window: { [marker]: bridge },
});
const emit = (stream, data) =>
  (handlers["shell:p:" + stream] || []).forEach((cb) => cb(data));
const count = () =>
  Object.values(handlers).reduce((n, callbacks) => n + callbacks.length, 0);

// Load the actual generated module and verify both legacy and context calls.
globalThis.window = {};
const calls = [];
for (const method of ["spawn", "run"]) {
  window["Lune.Plugins.Shell." + method] = async (args) => {
    calls.push(args);
    return "ok";
  };
}
const { lune } = await import("data:text/javascript;base64," + Buffer.from(runtime).toString("base64"));
const legacy = { command: "echo", args: ["hello"] };
const context = { ...legacy, cwd: "/project with spaces", env: { VALUE: "hello", REMOVE: null } };
await lune.Shell.spawn(legacy);
await lune.Shell.run(context);
assert.deepEqual(calls, [legacy, context]);

// Even sharing exactly the same callbacks must create independent subscriptions.
let lines = [],
  exits = [];
const opts = {
  stdout: (d) => lines.push(d.line),
  stderr: (d) => lines.push(d.line),
  exit: (d) => exits.push(d.code),
};
const first = shell.listen("p", opts);
const second = shell.listen("p", opts);
emit("stdout", { line: "both" });
assert.deepEqual(lines, ["both", "both"]);
first();
first();
assert.equal(count(), 3);
emit("stderr", { line: "remaining" });
assert.deepEqual(lines, ["both", "both", "remaining"]);
emit("exit", { code: 7 });
assert.deepEqual(exits, [7]);
assert.equal(count(), 0);
second();

// Every listener receives completion; cleanup must not interfere with dispatch.
exits = [];
shell.listen("p", { exit: () => exits.push("a") });
shell.listen("p", { exit: () => exits.push("b") });
emit("exit", { code: 0 });
assert.deepEqual(exits, ["a", "b"]);
assert.equal(count(), 0);

// Output-only subscriptions clean up without a user-provided exit callback.
for (let i = 0; i < 100; i++) {
  const dispose = shell.listen("p", { stdout() {} });
  if (i % 2) emit("exit", { code: 0 });
  dispose();
  assert.equal(count(), 0);
}

// Clean up before calling user code, even if that code throws.
shell.listen("p", {
  stdout() {},
  exit() {
    throw new Error("callback failure");
  },
});
assert.throws(() => emit("exit", { code: 0 }), /callback failure/);
assert.equal(count(), 0);

// A new subscription installed inside an exit callback survives old cleanup.
let next;
shell.listen("p", {
  exit() {
    next = shell.listen("p", { stdout() {} });
  },
});
shell.listen("p", { exit() {} });
emit("exit", { code: 0 });
assert.equal(count(), 2);
next();
assert.equal(count(), 0);

// Preserve the legacy broad unlisten method and harmless repeated disposal.
const dispose = shell.listen("p", opts);
shell.listen("p", opts);
shell.unlisten("p");
dispose();
assert.equal(count(), 0);
