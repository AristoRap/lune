# Error Handling

When a Crystal binding raises an exception, the JavaScript `Promise` rejects with a `LuneError` instance — a proper `Error` subclass you can inspect with `instanceof`, catch in a typed `catch` block, and see in DevTools stack traces.

---

## `LuneError`

`LuneError` extends the native `Error` class and adds a machine-readable `code`:

```ts
class LuneError extends Error {
  readonly code: string; // machine-readable error type
  // err.message — inherited from Error, holds the human-readable description
}
```

Import it from the runtime module:

```js
import { LuneError } from "../lunejs/runtime/runtime.js";
```

---

## Generic exceptions

If a Crystal method raises a plain `Exception`, the promise rejects with a `LuneError` whose `code` is `"error"` and `message` is the exception message:

```crystal
@[Lune::Bind]
def divide(a : Int32, b : Int32) : Int32
  raise "division by zero" if b == 0
  a / b
end
```

```js
import { LuneError } from "../lunejs/runtime/runtime.js";

try {
  await api.Math.divide(10, 0);
} catch (err) {
  console.log(err instanceof LuneError); // true
  console.log(err.code); // "error"
  console.log(err.message); // "division by zero"
}
```

---

## `Lune::Error` — typed errors

For errors you want the frontend to branch on, raise a `Lune::Error` with a machine-readable `code`:

```crystal
@[Lune::Bind]
def get_user(id : Int32) : String
  user = find_user(id)
  raise Lune::Error.new("not_found", "User ##{id} was not found") unless user
  user.to_json
end
```

In JavaScript, use `instanceof` or branch on `code`:

```js
import { LuneError } from "../lunejs/runtime/runtime.js";

try {
  const user = await api.Users.getUser(99);
} catch (err) {
  if (err instanceof LuneError && err.code === "not_found") {
    showNotFoundMessage();
  } else {
    throw err; // re-throw unexpected errors
  }
}
```

You can also subclass `Lune::Error` in Crystal for reuse across bindings:

```crystal
class NotFoundError < Lune::Error
  def initialize(resource : String)
    super("not_found", "#{resource} was not found")
  end
end

class UnauthorizedError < Lune::Error
  def initialize
    super("unauthorized", "you do not have permission")
  end
end
```

---

## TypeScript pattern

With TypeScript, `instanceof LuneError` narrows the type automatically — no custom type guard needed:

```ts
import { LuneError } from "../lunejs/runtime/runtime.js";

try {
  await api.Users.getUser(99);
} catch (err) {
  if (err instanceof LuneError) {
    // err is typed as LuneError here
    switch (err.code) {
      case "not_found":
        return showNotFoundMessage();
      case "unauthorized":
        return redirectToLogin();
      default:
        console.error("Unexpected:", err.message);
    }
  }
}
```
