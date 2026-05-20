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

The runtime declarations include:

```ts
export interface LuneEnvironment {
  os: "darwin" | "linux" | "windows";
  arch: string;
  devtools: boolean;
}

export interface LuneError {
  code: string;
  error: string;
}

export declare function on(name: string, cb: (data: unknown) => void): void;
export declare function once(name: string, cb: (data: unknown) => void): void;
export declare function off(name: string, cb?: (data: unknown) => void): void;
export declare function emit(name: string, data?: unknown): Promise<void>;

export declare function quit(): Promise<void>;
export declare function openUrl(url: string): Promise<void>;
export declare function environment(): LuneEnvironment;

export declare function homeDir(): Promise<string>;
export declare function tempDir(): Promise<string>;
export declare function downloadsDir(): Promise<string>;
export declare function appDataDir(): Promise<string>;
```

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
import { System, Events } from "../lunejs/runtime/runtime.js";
import type { LuneError } from "../lunejs/runtime/runtime.js";

// Fully typed — autocomplete works here
const result = await api.FileModule.read("/tmp/hello.txt");

// environment() returns LuneEnvironment
const env = await System.environment();
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

Events.on("progress", (data) => {
  const { done, total } = data as ProgressEvent;
  updateProgressBar(done / total);
});
```

---

## Handling errors with types

Use the `LuneError` interface from `runtime.d.ts`:

```ts
import type { LuneError } from "../lunejs/runtime/runtime.js";

function isLuneError(e: unknown): e is LuneError {
  return typeof e === "object" && e !== null && "code" in e;
}

try {
  await api.FileModule.read("/nonexistent");
} catch (e) {
  if (isLuneError(e)) {
    console.error(`[${e.code}] ${e.error}`);
  }
}
```
