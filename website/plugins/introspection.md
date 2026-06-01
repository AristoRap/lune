# Introspection

> Exposes the app's live RPC contract — every procedure and the custom types it references — to the frontend.

|                  |                          |
| ---------------- | ------------------------ |
| **Config key**   | `introspection`          |
| **JS namespace** | `Introspection`          |
| **Core**         | No                       |
| **Phases**       | Bindable · WebviewInject |
| **Hard deps**    | —                        |
| **Platforms**    | macOS · Linux · Windows  |

Introspection turns the typed bridge contract into runtime-readable data. The same `Vow::Manifest` that drives the generated TypeScript client — every procedure (name, argument names/types, return type) plus the custom structs and enums those signatures reference — is served back to the frontend on demand. Useful for building an in-app API explorer, a devtools panel, or asserting in a test that the surface you expect is actually exposed.

The same contract is available from the CLI via [`lune doctor api`](../cli-reference#lune-doctor-api).

---

## Disabling

Active by default. Disable it in `lune.yml` like any built-in — the `Introspection.manifest` binding and the `window.__lune.manifest()` wrapper both disappear:

```yaml
plugins:
  disabled:
    - introspection
```

---

## The typed binding

`lune.Introspection.manifest()` returns a `Manifest` interface generated into `lunejs/runtime/runtime.d.ts`:

```js
import { lune } from "../lunejs/runtime/runtime.js";

const contract = await lune.Introspection.manifest();
console.log(contract.procedures.length, "procedures");
console.table(
  contract.procedures.map((p) => ({ name: p.name, returns: p.return_type })),
);
```

The shape is the manifest IR:

```ts
interface Manifest {
  procedures: ProcedureDescriptor[];
  types: TypeDescriptor[];
}
```

Because it returns a real typed value, the manifest's own `manifest` procedure appears in the result — the contract is complete and self-describing.

---

## The devtools wrapper

For quick console use, the plugin also injects a `window.__lune.manifest()` convenience wrapper over the same binding — **but only when the app runs with devtools enabled** (auto-on under `lune dev`):

```js
// From the browser console while running `lune dev`:
const contract = await window.__lune.manifest();
```

In a production build with devtools off, the wrapper is absent (`window.__lune.manifest` is `undefined`). The typed `lune.Introspection.manifest()` binding is always available while the plugin is enabled, regardless of devtools.

---

## JavaScript API

| Method     | Signature    | Description                                            |
| ---------- | ------------ | ------------------------------------------------------ |
| `manifest` | `manifest()` | Resolves with the live `Manifest` (procedures + types) |

The `window.__lune.manifest()` wrapper has the same signature and return value; it exists only with devtools on.

---

## Notes

- The manifest is computed on each call, so it always reflects the fully resolved binding set for the running app.
- This is the same `Vow::Manifest` consumed by the code generator and printed by `lune doctor api` — one source of truth for the contract.

---

## Platform notes

- **macOS** — Verified.
- **Linux** — Untested.
- **Windows** — Verified.
