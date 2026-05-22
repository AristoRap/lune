# TypeScript

Lune generates TypeScript declaration files alongside every build. Your frontend gets full autocomplete and type safety derived directly from Crystal method signatures — no manual type definitions needed.

---

## Generated files

Lune writes four files into `frontend/lunejs/`:

```
frontend/lunejs/
├── app/
│   ├── App.js       # binding stubs (runtime)
│   └── App.d.ts     # TypeScript declarations for your bindings
└── runtime/
    ├── runtime.js   # quit, openUrl, environment, on/once/off/emit
    └── runtime.d.ts # TypeScript declarations for runtime functions
```

These are regenerated automatically on every `lune dev` start and `lune build`.

---

## App.d.ts — binding types

For each class and its `@[Lune::Bind]` methods, Lune generates an interface. For example:

```crystal
class FileModule
  include Lune::Bindable

  @[Lune::Bind]
  def read(path : String) : String
    File.read(path)
  end

  @[Lune::Bind]
  def exists(path : String) : Bool
    File.exists?(path)
  end
end
```

Generates:

```ts
export interface FileModule {
  read(path: string): Promise<string>;
  exists(path: string): Promise<boolean>;
}

export interface Api {
  FileModule: FileModule;
}

export declare const api: Api;
export default api;
```

---

## runtime.d.ts — runtime types

The runtime declarations export a single nested `Lune` object plus a short alias `lune = Lune.Plugins`, so every built-in lives at `lune.<Plugin>.<method>` (e.g. `lune.System.quit`, `lune.Events.on`, `lune.Filesystem.homeDir`). Third-party plugins published via `Lune.use` are top-level named exports alongside `Lune` and `LuneError` — not nested under `lune`.

The exact shape is generated per project from the registered plugin set, so the snippet below is illustrative:

```ts
export class LuneError extends Error {
  readonly code: string;
}

export interface LuneEnvironment {
  os: "darwin" | "linux" | "windows";
  arch: string;
  devtools: boolean;
}

export const Lune: {
  Plugins: {
    System: {
      quit(): Promise<void>;
      openUrl(url: string): Promise<void>;
      environment(): Promise<LuneEnvironment>;
    };
    Events: {
      on(name: string, cb: (data: unknown) => void): void;
      once(name: string, cb: (data: unknown) => void): void;
      off(name: string, cb?: (data: unknown) => void): void;
      emit(name: string, data?: unknown): Promise<void>;
    };
    Filesystem: {
      homeDir(): Promise<string>;
      tempDir(): Promise<string>;
      downloadsDir(): Promise<string>;
      appDataDir(): Promise<string>;
    };
    // …all other built-in plugins…
  };
};
export const lune: typeof Lune.Plugins;
```

For the full per-plugin signature list see the [Plugins](../plugins/) reference — each page documents its JS surface, which is what shows up in `runtime.d.ts`.

---

## Setting up TypeScript in a scaffolded project

The `--template vue` scaffold creates a TypeScript project out of the box. For a vanilla project, you can add TypeScript support to Vite manually:

```sh
npm install -D typescript
```

Create a `tsconfig.json` at the frontend root:

```json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "noEmit": true
  },
  "include": ["src"]
}
```

Then rename your entry point from `.js` to `.ts` and update `vite.config.js` to `vite.config.ts`.

---

## Importing with types

```ts
import api from "../lunejs/app/App.js";
import { lune } from "../lunejs/runtime/runtime.js";
import type { LuneError } from "../lunejs/runtime/runtime.js";

// Fully typed — autocomplete works here
const result = await api.FileModule.read("/tmp/hello.txt");

// environment() returns LuneEnvironment
const env = await lune.System.environment();
if (env.os === "darwin") {
  // macOS-specific code
}
```

---

## Typing event payloads

Events carry `unknown` data by default. Cast or validate at the call site:

```ts
interface ProgressEvent {
  done: number;
  total: number;
}

lune.Events.on("progress", (data) => {
  const { done, total } = data as ProgressEvent;
  updateProgressBar(done / total);
});
```

---

## Handling errors with types

`LuneError` is a real `Error` subclass, so `instanceof` narrows automatically — no custom type guard needed:

```ts
import { LuneError } from "../lunejs/runtime/runtime.js";

try {
  await api.FileModule.read("/nonexistent");
} catch (e) {
  if (e instanceof LuneError) {
    console.error(`[${e.code}] ${e.message}`);
  }
}
```

See [Error Handling](./error-handling) for the full pattern including typed code branches.
