# Windows Setup Guide

This guide documents the manual setup required to develop Lune on Windows.

## Prerequisites

- Visual Studio 2022 or later with C++ build tools
- Crystal 1.20.2+ (MSVC target)
- Git and PowerShell

## Step 1: Install WebView2 SDK Headers

The webview library requires Microsoft's WebView2 SDK headers. They're not included in the repository.

### Download WebView2 NuGet Package

```powershell
# Download nuget.exe
$nugetUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$nugetPath = "C:\temp\nuget.exe"
New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $nugetUrl -OutFile $nugetPath

# Download WebView2 package
& $nugetPath install Microsoft.Web.WebView2 -OutputDirectory "C:\temp\webview2"

# Find the include directory
$includeDir = Get-ChildItem "C:\temp\webview2" -Filter "Microsoft.Web.WebView2.*" -Directory | Select-Object -First 1
$cpathValue = Join-Path $includeDir.FullName "build\native\include"
```

### Set Environment Variable

Set `CPATH` to point to the WebView2 headers:

```powershell
# Persistent (User scope)
[Environment]::SetEnvironmentVariable("CPATH", $cpathValue, "User")

# Or session-only (current PowerShell only)
$env:CPATH = $cpathValue
```

## Step 2: Install Crystal Dependencies

```powershell
cd C:\Users\aris\code\lune
shards install --skip-postinstall
```

The `--skip-postinstall` flag skips the Unix-only Makefile-based build step (webview binaries are header-only on Windows).

## Step 3: Build Lune CLI

> **Blocker:** real `crystal build` on Windows MSVC is currently broken in **every released Crystal**, including 1.20.2. The bug is tracked at [crystal-lang/crystal#16929](https://github.com/crystal-lang/crystal/issues/16929) — `Process.initialize` references `LibC::PidT`, which doesn't exist on the Win32 stdlib. The fix landed in [crystal-lang/crystal#16933](https://github.com/crystal-lang/crystal/pull/16933) on May 13, 2026 and is targeted for **Crystal 1.21.0** (not yet released). Lune cannot go below 1.20.1 because it depends on `Fiber::ExecutionContext` (introduced in 1.20.1).
>
> Until 1.21 ships, the steps below are reference material — none of them produce a _functional_ Windows binary.

### Real build (once Crystal 1.21+ is available)

```powershell
crystal build src/lune_cli.cr -o bin/lune.exe -Dpreview_mt -Dexecution_context
```

Or via shards:

```powershell
shards build --release -Dpreview_mt -Dexecution_context
```

### Mocked build (compile-only sanity check)

Useful only for confirming your toolchain links cleanly. The resulting binary's capabilities are all stubbed and it does not run Lune apps:

```powershell
crystal build src/lune_cli.cr -o bin/lune.exe -Dpreview_mt -Dexecution_context -D lune_native_test_mock
```

## Known Limitations

- **Building a runnable Windows binary is blocked on Crystal 1.21+.** See PR #16933 above.
- **Running Specs**: `crystal spec` fails for the same reason — Crystal's spec runner uses `Process.new(pid)`. Type-checking with `--no-codegen` is what CI runs today.
- **WebView2 Runtime**: Once the build works, developers and end-users need the WebView2 runtime installed on Windows 10 and earlier (Windows 11+ includes it).
- **Real-hardware verification**: the Win32 implementations in v0.11.0 have only been compile-checked. Behaviour can't be confirmed until 1.21 lands and the per-capability walkthrough in [`website/guide/windows-checklist.md`](website/guide/windows-checklist.md) can be executed.

## Troubleshooting

### `CPATH is not set`

If you get compilation errors about missing `WebView2.h`:

```powershell
# Check CPATH
$env:CPATH

# Set it if missing (replace path as needed)
$env:CPATH = "C:\temp\webview2\Microsoft.Web.WebView2.1.0.3967.48\build\native\include"
```

### Build Fails with `undefined constant LibC::PidT`

Expected on Crystal 1.20.x. Wait for 1.21.0. If you need to test the toolchain plumbing in the meantime, the mocked build above will link cleanly but produces a non-functional binary.

## References

- [Lune README](README.md) — Platform support and quick start
- [Webview Library](lib/webview/README.md) — Raw webview bindings
- [Changelog v0.11.0](CHANGELOG.md) — Windows port details
- [Crystal Language](https://crystal-lang.org) — Language docs
