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

const result = await api.MathModule.Add(2, 3); // 5
const upper = await api.MathModule.ToUpper("hello"); // "HELLO"
```

All binding calls return a `Promise`, regardless of whether the Crystal method is synchronous.

---

## Method naming

Crystal methods use `snake_case`. Lune converts them to `PascalCase` (upper camel case) using Crystal's built-in `camelcase`:

| Crystal         | JavaScript    |
| --------------- | ------------- |
| `greet`         | `Greet`       |
| `slow_echo`     | `SlowEcho`    |
| `get_user_name` | `GetUserName` |

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
await api.Database.Queries.FindUser(42);
```

---

## Type mapping

Lune maps Crystal types to TypeScript types for the generated `.d.ts` file:

| Crystal                                | TypeScript            |
| -------------------------------------- | --------------------- |
| `String`                               | `string`              |
| `Bool`                                 | `boolean`             |
| `Int32`, `Int64`, `Float32`, `Float64` | `number`              |
| `Nil`                                  | `void`                |
| `Array`                                | `any[]`               |
| `Hash`                                 | `Record<string, any>` |
| Custom struct/class                    | `Record<string, any>` |

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

Every class that includes `Lune::Bindable` gets an `@app` instance variable injected automatically when `app.install` is called. Use it to push events back to the frontend from inside a bound method:

```crystal
class ProcessModule
  include Lune::Bindable

  @[Lune::Bind(async: true)]
  def run(paths : Array(String)) : Nil
    paths.each_with_index do |path, i|
      do_work(path)
      @app.emit("progress", {"done" => i + 1, "total" => paths.size})
    end
  end
end
```

No constructor argument needed — `@app` is set by the framework at install time. You can call `@app.emit` anywhere in the class, including background fibers spawned from a binding.

---

## Async bindings

By default, binding callbacks block the calling fiber. For operations that may take time (file I/O, network, sleep), use `async: true` to run the method in a separate fiber:

```crystal
class FileModule
  include Lune::Bindable

  @[Lune::Bind(async: true)]
  def read_file(path : String) : String
    File.read(path)
  end
end
```

From JavaScript the call is identical — it still returns a `Promise`. The difference is that async bindings don't block the WebView event loop, so the UI stays responsive during long operations.

---

## Importing namespaces

The default export is `api`, an object containing all registered namespaces:

```js
import api from "../lunejs/app/App.js";

await api.GreetModule.Greet("world");
```

Named exports are also available for each top-level namespace, which can be more convenient:

```js
import { GreetModule, MathModule } from "../lunejs/app/App.js";

await GreetModule.Greet("world");
await MathModule.Add(1, 2);
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

## Low-level: `Lune::Installable`

`Lune::Bindable` is built on top of `Lune::Installable`, a minimal interface with a single `install(app)` method. You can implement it directly when you need full control — for example, to register bindings with dynamic names or conditional logic:

```crystal
class MyPlugin
  include Lune::Installable

  def install(app : Lune::App)
    app.bind(
      name: "ping",
      namespace: "MyPlugin",
      args: [] of String,
      return_type: "String",
      async: false,
    ) do |_args|
      JSON.parse("\"pong\"")
    end
  end
end
```

This is rarely needed — prefer `Lune::Bindable` for most cases.
