---
layout: home

hero:
  name: Lune
  text: Desktop apps for Crystal
  tagline: Expose Crystal methods to a web frontend with zero boilerplate. One binary. Typed API. Hot reload.
  actions:
    - theme: brand
      text: Get Started
      link: /getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/AristoRap/lune

features:
  - title: Zero-boilerplate bridge
    details: Annotate a Crystal method with @[Lune::Bind] and it is automatically available as a JavaScript function — no IPC wiring, no serialization code.
  - title: Typed TypeScript API
    details: Lune generates App.d.ts alongside every build. Your frontend gets full autocomplete and type safety derived directly from Crystal method signatures.
  - title: Single self-contained binary
    details: The frontend is compiled into the Crystal binary at build time. Ship one file — no Electron, no Node runtime, no bundled Chromium.
  - title: Hot reload in dev
    details: lune dev starts your Vite dev server and Crystal backend together. Save a file and the frontend reloads instantly; change Crystal and it recompiles.
  - title: macOS & Linux
    details: Uses the native WebView on each platform — WKWebView on macOS, WebKitGTK on Linux. No extra runtime to install.
  - title: Familiar frontend tooling
    details: Works with any Vite-based frontend — Vanilla JS, Vue, React, Svelte. Templates for Vanilla and Vue ship out of the box.
---
