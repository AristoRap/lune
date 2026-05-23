# Bindings

Bindings are how Crystal methods become callable JavaScript functions. Lune uses a compile-time annotation to discover and register them — no boilerplate, no code generation step you have to run.

---

## Basic usage

Include `Lune::Bindable` in a class and annotate methods with `@[Lune::Bind]`:

```crystal
require "lune"

class MathModule
  include Lune::Bindable

  @[Lune::Bind]
  def add(a : Int32, b : Int32) : Int32
    a + b
  end

  @[Lune::Bind]
  def to_upper(s : String) : String
    s.upcase
  end
end
```

Register the module with your app:

```crystal
app = Lune::App.new
app.install(MathModule.new)
```

In JavaScript:

```js
import api from "../lunejs/app/App.js";

const result = await api.MathModule.add(2, 3); // 5
const upper = await api.MathModule.toUpper("hello"); // "HELLO"
```

All binding calls return a `Promise`, regardless of whether the Crystal method is synchronous.

---

## Method naming

Crystal methods use `snake_case`. Lune converts them to `camelCase` using Crystal's built-in `camelcase`:

| Crystal         | JavaScript    |
| --------------- | ------------- |
| `greet`         | `greet`       |
| `slow_echo`     | `slowEcho`    |
| `get_user_name` | `getUserName` |

Parameter names are preserved as-is in the generated `.d.ts`. A method `def slow_echo(name : String)` produces `slowEcho(name: string)`.

---

## Namespaces

The Crystal class name becomes the JavaScript namespace. Nested classes using `::` become nested objects:

```crystal
class Database::Queries
  include Lune::Bindable

  @[Lune::Bind]
  def find_user(id : Int32) : String
    # ...
  end
end
```

```js
await api.Database.Queries.findUser(42);
```

---

## Type mapping

Lune maps Crystal types to TypeScript types for the generated `.d.ts` file. The mapping is **generic-aware** — parameterised collections produce the matching parameterised TypeScript type, and the rule applies recursively:

| Crystal                                | TypeScript                                |
| -------------------------------------- | ----------------------------------------- |
| `String`                               | `string`                                  |
| `Bool`                                 | `boolean`                                 |
| `Int32`, `Int64`, `Float32`, `Float64` | `number`                                  |
| `Nil`                                  | `void`                                    |
| `Array(T)`                             | `T[]` (e.g. `Array(String)` → `string[]`) |
| `Hash(K, V)`                           | `Record<K, V>`                            |
| `Tuple(A, B, ...)`                     | `[A, B, ...]`                             |
| Custom struct/class                    | `Record<string, any>`                     |

Bare `Array` / `Hash` (no parameters) fall back to `any[]` / `Record<string, any>`. Use `Array(T)` / `Hash(K, V)` in signatures whenever you can — the generated `.d.ts` propagates the parameter, so frontend code keeps its types without `as` casts.

Custom types must be JSON-serializable. Add `include JSON::Serializable` to your structs:

```crystal
struct User
  include JSON::Serializable

  getter id : Int32
  getter name : String
end

class UserModule
  include Lune::Bindable

  @[Lune::Bind]
  def current_user : User
    User.new(id: 1, name: "Alice")
  end
end
```

---

## Emitting events from a binding

Every class that includes `Lune::Bindable` gets an `@app` instance variable injected automatically when `app.install` is called. Use it to interact with the event bus from inside a bound method:

```crystal
class ProcessModule
  include Lune::Bindable

  @[Lune::Bind(async: true)]
  def run(paths : Array(String)) : Nil
    paths.each_with_index do |path, i|
      do_work(path)
      @app.event.emit("progress", {"done" => i + 1, "total" => paths.size})
    end
  end
end
```

No constructor argument needed — `@app` is set by the framework at install time. The full event bus API is available via `@app.event`: `@app.event.emit`, `@app.event.on`, `@app.event.once`, and `@app.event.off` — all usable anywhere in the class, including background fibers spawned from a binding. See the [Event](./event) guide for the complete API.

---

## Async bindings

By default, binding callbacks run on the main thread. For operations that may take time (file I/O, network, sleep), use `async: true` to run the method on a dedicated OS thread:

```crystal
class FileModule
  include Lune::Bindable

  @[Lune::Bind(async: true)]
  def read_file(path : String) : String
    File.read(path)
  end
end
```

From JavaScript the call is identical — it still returns a `Promise`. The difference is that async bindings run on a background fiber in a shared thread pool (`Fiber::ExecutionContext::Parallel`), so `sleep`, `Channel`, HTTP, and other blocking operations all work correctly and the UI stays responsive.

---

## Background tasks

Because Lune's native event loop owns the main thread, plain `spawn` does **not** work for long-running background tasks — fibers spawned into the default (single-threaded cooperative) context never get scheduled while the window is open.

Use `app.async` instead:

```crystal
app.async do
  loop do
    app.event.emit("tick", Time.utc.to_rfc3339)
    sleep 1.second
  end
end

Lune.run(app, ...) { ... }
```

`app.async` spawns a fiber into a shared background thread pool (`Fiber::ExecutionContext::Parallel`) — so `sleep`, channels, and IO all work as expected. An optional name helps with debugging:

```crystal
app.async("live-clock") { ... }
```

---

## Importing namespaces

The default export is `api`, an object containing all registered namespaces:

```js
import api from "../lunejs/app/App.js";

await api.GreetModule.greet("world");
```

Named exports are also available for each top-level namespace, which can be more convenient:

```js
import { GreetModule, MathModule } from "../lunejs/app/App.js";

await GreetModule.greet("world");
await MathModule.add(1, 2);
```

Both import styles refer to the same underlying stubs.

---

## Multiple modules

You can install multiple modules at once:

```crystal
app.install(
  GreetModule.new,
  FileModule.new,
  DatabaseModule.new,
)
```

Each module gets its own namespace in the generated API.

---

## User bindings vs plugin bindings

`Lune::Bindable` works on its own, and it also works on subclasses of `Lune::Plugin`. The difference is which JS file the generated stubs land in:

- **`include Lune::Bindable`** alone — user binding. Stubs go to `lunejs/app/App.js`. Namespace is the Crystal class path verbatim (`Demo` → `Demo`/`api.Demo`, `Foo::Bar` → `Foo.Bar`/`api.Foo.Bar`).
- **`class MyPlugin < Lune::Plugin` + `include Lune::Bindable`** — plugin binding. Stubs go to `lunejs/runtime/runtime.js`. The Crystal class path 1-to-1 maps to the JS path: `Lune::Plugins::Tray.show` → `Lune.Plugins.Tray.show` or `lune.Tray.show` (the `lune` alias is shorthand for `Lune.Plugins` baked into the generated runtime).

The bridge id is identical in shape — `<Namespace>.<method>` where `Namespace` is `@type.name.stringify` with `::` swapped for `.`. No special prefix on plugin ids.

Plugin authors get more than bindings — descriptors, dependency declarations, a `config do … end` macro, lifecycle hooks (`setup`, `init_webview`, `shutdown`), and platform gates. See [Authoring plugins](./authoring-plugins) for the full plugin API.

---

## Low-level: `Lune::Installable`

`Lune::Bindable` is built on top of `Lune::Installable`, a minimal interface with a single `install(app)` method. You can implement it directly when you need full control — for example, to register bindings with dynamic names or conditional logic:

```crystal
class MyPlugin
  include Lune::Installable

  def install(app : Lune::App)
    app.bind(
      namespace: "MyPlugin",
      method: "ping",
      args: [] of String,
      return_type: "String",
      async: false,
      arg_names: [] of String,
    ) do |_args|
      JSON.parse("\"pong\"")
    end
  end
end
```

This is rarely needed for application code — prefer `Lune::Bindable` for most cases.
