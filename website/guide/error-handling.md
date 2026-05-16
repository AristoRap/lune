# Error Handling

When a Crystal binding raises an exception, the JavaScript `Promise` rejects. Lune provides a structured error envelope so the frontend can inspect the failure and branch on error type.

---

## The error envelope

All rejected promises carry an object with two fields:

```ts
interface LuneError {
  code: string; // machine-readable error code
  error: string; // human-readable message
}
```

---

## Generic exceptions

If a Crystal method raises a plain `Exception`, the frontend receives:

```json
{ "code": "error", "error": "the exception message" }
```

Example:

```crystal
@[Lune::Bind]
def divide(a : Int32, b : Int32) : Int32
  raise "division by zero" if b == 0
  a / b
end
```

```js
try {
  await api.Math.Divide(10, 0);
} catch (e) {
  console.log(e.code); // "error"
  console.log(e.error); // "division by zero"
}
```

---

## `Lune::Error` — typed errors

For errors you want the frontend to act on differently, subclass `Lune::Error` and provide a machine-readable `code`:

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

Raise them from bindings just like any other exception:

```crystal
@[Lune::Bind]
def get_user(id : Int32) : String
  user = find_user(id)
  raise NotFoundError.new("User ##{id}") unless user
  user.to_json
end
```

In JavaScript, branch on `code`:

```js
try {
  const user = await api.Users.GetUser(99);
} catch (e) {
  if (e.code === "not_found") {
    showNotFoundMessage();
  } else if (e.code === "unauthorized") {
    redirectToLogin();
  } else {
    console.error("Unexpected error:", e.error);
  }
}
```

---

## TypeScript pattern

If you are using TypeScript, define a type guard for `LuneError`:

```ts
import type { LuneError } from "../lunejs/runtime/runtime.js";

function isLuneError(e: unknown): e is LuneError {
  return typeof e === "object" && e !== null && "code" in e && "error" in e;
}

try {
  await api.Users.GetUser(99);
} catch (e) {
  if (isLuneError(e) && e.code === "not_found") {
    // handle
  }
}
```
