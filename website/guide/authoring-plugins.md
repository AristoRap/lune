# Authoring plugins

Lune's built-in plugins (Tray, Clipboard, FileWatch, …) are written against the same API a third-party shard would use. There's no privileged path — if you can declare a class that subclasses `Lune::Plugin`, you can publish a shard that drops into someone else's `Lune.run` block as a peer.

This guide walks the API top to bottom: shard layout, descriptor, config DSL, lifecycle, bindings, JS namespace, platform gating.

---

## Shard layout

A Lune plugin is a normal Crystal shard. Minimum viable layout:

```
my-plugin/
├── shard.yml
├── src/
│   └── my_plugin.cr
└── spec/
    └── my_plugin_spec.cr
```

`shard.yml`:

```yaml
name: my_plugin
version: 0.1.0

dependencies:
  lune:
    github: aristorap/lune
    version: ~> 0.12
```

Pin to the Lune minor — the plugin API is stable within a minor.

The user's consuming app then adds your shard to their own `shard.yml` and calls `Lune.use(MyPlugin.new)` in `main.cr` before `Lune.run`.

---

## The plugin class

Subclass `Lune::Plugin` and write your bindings against it. The Crystal class path becomes the JS namespace 1-to-1 — every `::` becomes a `.` on the JS side — so the shape you pick in Crystal is the shape consumers type. Two equally valid shapes:

| Crystal                               | JS namespace              | Bridge id               | `opts` accessor  |
| ------------------------------------- | ------------------------- | ----------------------- | ---------------- |
| `class MyPlugin < Lune::Plugin`       | `MyPlugin.doStuff()`      | `MyPlugin.do_stuff`     | `opts.my_plugin` |
| `module MyPlugin; class MyModule < …` | `MyPlugin.MyModule.foo()` | `MyPlugin.MyModule.foo` | `opts.my_module` |

Both are first-class. Use the flat form when your plugin is one cohesive thing; use the nested form when you want to group multiple plugins under a shared shard namespace (e.g. `LuneAuth::OAuth`, `LuneAuth::Sessions`).

> **`Lune::Plugins::` is reserved.** Built-in plugins live there. `Lune.use` raises `Lune::RegistrationError` if a plugin class with that prefix isn't on the blessed-built-ins list, so third-party shards can't accidentally squat on the framework namespace. Pick a top-level namespace named for your shard (`LuneAuth::OAuth`, not `Lune::Plugins::OAuth`).

> **Heads up on the `opts` accessor.** The `config do … end` macro derives the accessor from the **simple class name** (the last `::` segment) — `MyPlugin::MyModule` ⇒ `opts.my_module`. If two plugins share a simple class name (e.g. `LuneAuth::Session` and `LuneCache::Session`), they'd both try to claim `opts.session`. `Lune.use` catches this and raises `Lune::RegistrationError` at registration time — the plugin registered second is the one that fails. Either pick a distinctive class name, or pass an explicit accessor to the macro: `config(:my_session) do …`.

A worked example:

```crystal
# src/my_mqtt.cr
require "lune"

class MyMqtt < Lune::Plugin
  include Lune::Bindable

  DESCRIPTOR = Descriptor.new(
    id:        :my_mqtt,
    label:     "MyMqtt",
    soft_deps: [:events],          # optional — degrades gracefully if absent
    deps:      [] of Symbol,       # required — plugin disables itself if missing
    platforms: [:darwin, :linux, :win32],
  )

  def descriptor : Descriptor
    DESCRIPTOR
  end

  config do
    property broker : String = "tcp://localhost:1883"
    property on_message : (String, String -> Nil)? = nil
  end

  def setup(ctx : SetupCtx) : Nil
    # Called once before any binding install. Pull what you need off ctx —
    # `options`, `handle`, `on_quit` — and store it on `self`.
    @client = MQTT::Client.new(@config.broker)
  end

  @[Lune::Bind(async: true)]
  def publish(topic : String, payload : String) : Nil
    @client.publish(topic, payload)
  end
end
```

A consumer wires it in:

```crystal
require "lune"
require "my_mqtt"

Lune.use(MyMqtt.new)
# `Lune.use` is variadic — register several at once if you prefer:
# Lune.use(MyMqtt.new, MyTelemetry.new, OAuth.new)

app = Lune::App.new
Lune.run(app, assets: "frontend/dist") do |opts|
  opts.my_mqtt.broker = ENV["MQTT_BROKER"]
end
```

Run `lune doctor --plugins` from the project to verify the registry actually sees what you registered. The flag compiles the entry point in inspect mode (`-Dlune_inspect`) and lists every plugin that survived to `Lune.run` — the WYSIWYG view, since it's the live registration set rather than a textual guess.

And in JS:

```js
import { MyMqtt } from "../lunejs/runtime/runtime.js";

await MyMqtt.publish("topics/hello", "world");
```

Third-party plugins sit at the **top level** of `runtime.js`, alongside `Lune` and `LuneError`. The `lune` named export is a shorthand for `Lune.Plugins` and only covers Lune's own built-ins (`lune.Tray.show()`, `lune.Clipboard.read()`, …); a plugin you publish exports as its own top-level name, not under `lune`.

---

## Descriptor

`Descriptor` is a `record` declared on every plugin. Fields:

| Field       | Type            | Default                     | Description                                                             |
| ----------- | --------------- | --------------------------- | ----------------------------------------------------------------------- |
| `id`        | `Symbol`        | required                    | Stable identifier. Must be unique across all `Lune.use` calls.          |
| `label`     | `String`        | required                    | Human-readable name, used in `lune doctor` and log lines.               |
| `deps`      | `Array(Symbol)` | `[]`                        | **Hard** deps — plugin auto-disables if any aren't active.              |
| `soft_deps` | `Array(Symbol)` | `[]`                        | **Soft** deps — plugin stays active; warning is logged if any are gone. |
| `core`      | `Bool`          | `false`                     | `true` blocks the plugin from being excluded via `lune.yml`.            |
| `platforms` | `Array(Symbol)` | `[:darwin, :linux, :win32]` | OSes where the plugin runs. Filtered out elsewhere at registry build.   |

Use `soft_deps` for cross-plugin behavior you'd like but don't require (`Tray` soft-deps on `events` so menu clicks emit on the bus when present, falls back to direct callbacks when absent). Use `deps` only when your plugin genuinely can't function without the other.

---

## Config DSL

`config do … end` declares typed options inside the plugin class. The macro:

1. Generates a nested `Config` class with the declared properties.
2. Adds `@config : Config = Config.new` and `getter config : Config` to the plugin so you read settings off `self.config`.
3. Reopens `Lune::Options` with an accessor named after your plugin's simple class name underscored. `class MyPlugin` → `opts.my_plugin`, `class MqttBroker` → `opts.mqtt_broker`.

```crystal
class MyPlugin < Lune::Plugin
  config do
    property api_key : String = ""
    property timeout : Time::Span = 5.seconds
    property on_message : (String -> Nil)? = nil
  end

  def setup(ctx : SetupCtx) : Nil
    # ctx isn't needed for config — read it directly off @config.
    Lune.logger.info { "connecting with timeout=#{@config.timeout}" }
  end
end
```

Consumer:

```crystal
Lune.run(app, assets: "frontend/dist") do |opts|
  # Direct assignment:
  opts.my_plugin.api_key = "secret"

  # Or block-yield, identical semantics:
  opts.my_plugin do |c|
    c.timeout = 30.seconds
    c.on_message = ->(m : String) { Lune.logger.info { m } }
  end
end
```

Both forms mutate the same `@config` instance on the registered plugin, which is what `setup` later reads.

**Callbacks are first-class.** Procs can sit alongside scalars — no YAML hydration step, no `@[YAML::Field(ignore: true)]` shim. The config is plain Crystal code.

**lune.yml is registry-only.** Per-plugin sub-keys aren't parsed. If a user wants to set per-environment values they branch in code (`{% if flag?(:prod) %}`) or read `ENV[…]` in the `Lune.run` block.

---

## Lifecycle

Phases are opt-in via modules. Include only the ones you need; the compiler enforces the abstract method for each.

### `setup(ctx : SetupCtx)`

Always available — the default is a no-op. Called once per Lune run, before any binding install and before `init_webview` fires. The `SetupCtx` carries:

- `ctx.options` — the populated `Lune::Options` instance, including your `@config`.
- `ctx.handle : Void*` — the native window handle.
- `ctx.on_quit : -> Nil` — the runtime's quit callback. Call it to trigger app shutdown.

```crystal
def setup(ctx : SetupCtx) : Nil
  @handle = ctx.handle
end
```

### `include Plugin::WebviewInject` → `init_webview(ctx : WebviewCtx)`

Include this when you need the webview itself (`wv.bind`, `wv.dispatch`, `wv.eval`). For boot-time JS injection, prefer `init_js` over `wv.init` directly. `WebviewCtx` carries `wv`, `handle`, `app`, and the active plugin-id set so you can check `ctx.dep_active?(:events)`.

```crystal
include Plugin::WebviewInject

def init_webview(ctx : WebviewCtx) : Nil
  return unless ctx.dep_active?(:events)
  ctx.app.events.on("my-event") { |data| handle(data) }
end
```

### `include Plugin::Lifecycle` → `shutdown`

Called on quit. Use this for plugins that hold OS resources (sockets, file watchers, threads). The runtime guarantees `shutdown` fires before the window is destroyed.

```crystal
include Plugin::Lifecycle

def shutdown : Nil
  @watcher.try(&.close)
end
```

### `include Plugin::MainContextAware` → `set_main_context(ctx : MainCtx)`

Wired after the bridge is up and the binding set is final. Use this if you need to orchestrate the main webview at runtime (open a secondary window, evaluate JS into the main wv, look up siblings). `MainCtx` exposes `wv`, `app`, `resolved` (the `ResolvedSet`), `bindings`, plus a `find(id : Symbol)` helper.

---

## Bindings

Plugin bindings work exactly like user bindings — `include Lune::Bindable` and annotate methods with `@[Lune::Bind]`. The only difference is where the generated stub lands (`runtime/runtime.js` for plugins, `app/App.js` for user code) — same macro, same id formula, same camelCase rule.

```crystal
@[Lune::Bind]
def publish(topic : String, payload : String) : Nil
  @client.publish(topic, payload)
end

@[Lune::Bind(async: true)]
def fetch_remote(url : String) : String
  HTTP::Client.get(url).body
end
```

`async: true` runs the binding on a background thread (`Fiber::ExecutionContext::Parallel`), the same pool `app.async` uses. Use it for anything that blocks (network, slow file IO).

For TS-side overrides on the generated stub (custom argument names, JS-side `JSON.stringify` wrappers, full return type override), add `@[Lune::BindOverride]` on the same method — see [Bindings](./bindings) for the full table.

---

## JS-side surface

Lune generates nested namespace exports in `runtime.js` based on each plugin's Crystal class path. First-party plugins live under `Lune.Plugins`; third-party plugins land as their own top-level named exports:

```js
// First-party plugins under Lune.Plugins, with `lune` as the short alias.
export const Lune = {
  Plugins: {
    Tray:      { show(...) { ... }, ... },
    Clipboard: { read() { ... }, ... },
  },
};
export const lune = Lune.Plugins;

// Third-party plugins are their own top-level named exports.
export const MyPlugin   = { doStuff() { ... } };
export const MyDatabase = { Sessions: { open() { ... } } };
```

Consumers import what they need by name:

```js
import { lune, MyPlugin } from "../lunejs/runtime/runtime.js";

await lune.Tray.show("/assets/icon.png");
await MyPlugin.doStuff();
```

The Crystal namespace path determines the JS path. A plugin at top-level `class MyPlugin < Lune::Plugin` lands at `MyPlugin.doStuff()`. A plugin at `module MyDatabase; class Sessions < Lune::Plugin` lands at `MyDatabase.Sessions.open()`. Both forms work — pick the one whose call sites read best.

### `init_js`

Override `init_js : String?` to inject JS at boot. Use this for state your bindings need on the JS side (event listeners, polyfills, helper functions on `window.__lune`). The string is passed to `wv.init` once per window before any user code runs.

```crystal
def init_js : String?
  bm = BRIDGE_MARKER  # "__lune" — name of the helper-API object on window
  <<-JS
  (function(){
    window.#{bm}.myPluginReady = true;
  })();
  JS
end
```

**Re-entry contract**: `init_js` may be evaluated more than once if your plugin runs in multiple windows. Keep the JS idempotent — guard with `window.__lune.myPluginReady` or similar so multiple injections don't double-register listeners.

### `js_helpers` and `dts_helpers`

For methods that don't need a Crystal call (pure JS sugar like `Events.on`, `Events.off`), return the JS body from `js_helpers` and the matching `.d.ts` signatures from `dts_helpers`. They're stitched into the same namespace object the generated bindings live in.

```crystal
def js_helpers : String
  <<-JS
    onMessage(cb) { window.__lune.on("my-message", cb, -1); },
  JS
end

def dts_helpers : String
  <<-DTS
    onMessage(cb: (data: unknown) => void): void;
  DTS
end
```

---

## Platform gating

Set `platforms:` on the descriptor to declare which OSes your plugin runs on. Registry filters at construction:

```crystal
DESCRIPTOR = Descriptor.new(
  id: :my_plugin,
  label: "MyPlugin",
  platforms: [:darwin, :linux],   # no Windows
)
```

On a filtered-out platform, the plugin is dropped from `registry.all` — never gets `setup`, never installs bindings, never reaches the runtime generator. Users don't need a `lune.yml` exclusion.

Plugins with bindings that should give a graceful client-side error on unsupported platforms (rather than `TypeError: undefined.method`) override `unavailable_js_stub` and `unavailable_dts_stub`. Return the _body_ of the namespace object — the generator wraps it in `{}` and places it at the right path in the tree.

```crystal
def unavailable_js_stub(platform : Symbol) : String?
  ns = binding_namespace.gsub("::", ".")
  <<-JS
    ping() { return Promise.reject(new LuneError("UNAVAILABLE_ON_PLATFORM", "#{ns}.ping is not available on #{platform}")); },
  JS
end

def unavailable_dts_stub : String?
  <<-DTS
    ping(): Promise<void>;
  DTS
end
```

The same TS signatures are preserved cross-platform so consumer code type-checks identically; the difference is runtime behavior (live bindings vs rejecting stubs).

---

## Cross-plugin lookup

From `set_main_context` you can find a sibling plugin by id:

```crystal
include Plugin::MainContextAware

def set_main_context(ctx : MainCtx) : Nil
  if events = ctx.find(:events)
    @app = ctx.app
  end
end
```

`find` returns `Lune::Plugin?` — nil if the dep isn't active. Combine with `soft_deps:` to degrade gracefully.

---

## Native code

Plugins that call into platform APIs use standard Crystal shard conventions. Drop your `.m` / `.c` / `.h` files under `ext/`, declare them in `shard.yml`'s `targets:` block, and bind via `@[Link]` and `lib`. Lune doesn't standardize this — see the Crystal docs on native interop.

For platform-specific code in pure Crystal, use `{% if flag?(:darwin) %}` / `{% elsif flag?(:linux) %}` / `{% elsif flag?(:win32) %}` blocks. The compile-time flag matches the runtime `Lune::Plugins::CURRENT_PLATFORM` value.

---

## Testing

Plugins are testable in isolation via `Lune.with_plugins`, a spec helper that swaps the registration set around a block:

```crystal
require "spec"
require "lune"

describe MyPlugin::Plugin do
  it "publishes a message via the binding" do
    plugin = MyPlugin::Plugin.new

    Lune.with_plugins(plugin) do
      opts = Lune::Options.new
      opts.my_plugin.api_key = "test-key"
      plugin.setup(Lune::Plugin::SetupCtx.new(opts, Pointer(Void).null))

      # binding logic exercised through the plugin instance directly
      plugin.ping.should eq("pong")
    end
  end
end
```

`with_plugins` snapshots the existing registration, installs only the listed plugins for the duration of the block, then restores. It's the only sanctioned way to mutate `Lune.registered_plugins` from tests.

---

## Publishing checklist

Before tagging your first version:

- [ ] `shard.yml`: pin `lune` to a minor (`version: ~> 0.12`).
- [ ] Descriptor `id` is unique enough not to clash with any built-in or other shard. Convention: `:<shard_name>` or `:<shard_name>_<feature>`.
- [ ] If your plugin owns OS resources, `include Plugin::Lifecycle` and release them in `shutdown`.
- [ ] If the plugin only runs on some platforms, set `platforms:` and provide `unavailable_*_stub` overrides if you have bindings.
- [ ] Document the `opts.<id>.*` config block in your README.
- [ ] `crystal spec` clean — `with_plugins` keeps tests isolated.
- [ ] README mentions the consumer steps: add to `shard.yml`, `require`, `Lune.use(MyPlugin::Plugin.new)`.

---

## See also

- [Bindings](./bindings) — `@[Lune::Bind]`, `@[Lune::BindOverride]`, type mapping.
- [Events](./events) — the cross-plugin event bus.
- [How it works](./how-it-works) — runtime architecture and thread model.
