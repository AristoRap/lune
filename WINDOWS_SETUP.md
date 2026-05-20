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

## Step 3: Apply Crystal 1.20.2 Stdlib Fix

Crystal 1.20.2 (and all earlier released versions) have a compilation blocker: `Process.initialize` references `LibC::PidT`, which doesn't exist on Windows. The fix is documented in [crystal-lang/crystal#16933](https://github.com/crystal-lang/crystal/pull/16933) and is targeted for Crystal 1.21.0.

To work around this on Crystal 1.20.2, apply the fix manually to your Crystal installation:

1. Locate your Crystal stdlib `process.cr`:
   - MSVC build: `C:\Users\<username>\AppData\Local\Programs\Crystal\src\process.cr`
   - MinGW build: `C:\crystal-mingw\share\crystal\src\process.cr`

2. Open the file and find the section around line 599-604:
   ```crystal
   {% unless flag?(:interpreted) %}
     # :nodoc:
     def initialize(pid : LibC::PidT)
       @process_info = Crystal::System::Process.new(pid)
     end
   {% end %}
   ```

3. Remove the type annotation `LibC::PidT` from the parameter:
   ```crystal
   {% unless flag?(:interpreted) %}
     # :nodoc:
     def initialize(pid)
       @process_info = Crystal::System::Process.new(pid)
     end
   {% end %}
   ```

This allows the compiler to infer the type, which works correctly on Windows where `LibC::PidT` doesn't exist.

## Step 4: Build Native Libraries

Lune depends on two C libraries for Windows: sqlite3 and webview. Both must be built and placed where the linker can find them.

### sqlite3.lib

1. Download pre-compiled sqlite3 binaries from [sqlite.org](https://www.sqlite.org/download.html):
   ```powershell
   $url = "https://www.sqlite.org/2024/sqlite-dll-win-x64-3450000.zip"
   Invoke-WebRequest -Uri $url -OutFile "C:\temp\sqlite3.zip"
   Expand-Archive -Path "C:\temp\sqlite3.zip" -DestinationPath "C:\sqlite3"
   ```

2. Create the import library from the x64 Native Tools Command Prompt:
   ```cmd
   cd C:\sqlite3
   lib /def:sqlite3.def /machine:x64 /out:sqlite3.lib
   ```

### webview.lib

1. Clone and build the webview repository:
   ```cmd
   cd C:\temp
   git clone https://github.com/webview/webview
   cd webview
   ```

2. Configure and build with CMake (requires CMake and Ninja):
   ```cmd
   cmake -G Ninja -B build -S . -D CMAKE_BUILD_TYPE=Release
   cmake --build build
   ```

3. Copy the built libraries:
   ```cmd
   copy C:\temp\webview\build\core\webview.lib "C:\Users\aris\AppData\Local\Programs\Crystal\lib\"
   copy C:\temp\webview\build\core\webview.dll C:\Users\aris\code\lune\bin\
   ```

## Step 5: Build Lune CLI

Run from x64 Native Tools Command Prompt with environment variables set:

```cmd
set LIB=%LIB%;C:\sqlite3;C:\Users\aris\code\lune\lib\webview\ext
set PATH=%PATH%;C:\sqlite3
cd C:\Users\aris\code\lune
"C:\Users\aris\AppData\Local\Programs\Crystal\crystal.exe" build bin/lune.cr -o bin/lune.exe -Dpreview_mt -Dexecution_context
```

The executable will be at `C:\Users\aris\code\lune\bin\lune.exe`.

## Step 6: Run a Lune App (`lune dev`)

When the CLI spawns `crystal build` for your app, the child process inherits the parent shell's `LIB`. From a vanilla PowerShell or cmd, `LIB` is missing the MSVC base paths (CRT, kernel32, ucrt), so the link step fails with:

```
Cannot locate the .lib files for the following libraries: sqlite3
```

(misleading — it's the missing MSVC base libs that prevent the linker from even getting to sqlite3.)

The easiest workaround is to run `lune dev` from the **x64 Native Tools Command Prompt**, which has `LIB` already populated. If you must run from regular PowerShell, set `LIB` explicitly first:

```powershell
$msvcLib = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\lib\x64;C:\Program Files (x86)\Windows Kits\10\lib\10.0.26100.0\ucrt\x64;C:\Program Files (x86)\Windows Kits\10\lib\10.0.26100.0\um\x64"
$env:LIB = "$msvcLib;C:\sqlite3;C:\Users\aris\code\lune\lib\webview\ext"
$env:PATH = "$env:PATH;C:\sqlite3"
cd <your-lune-app>
C:\Users\aris\code\lune\bin\lune.exe dev
```

Replace the MSVC and Windows Kits version numbers with whatever's installed on your machine (check `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\` and `C:\Program Files (x86)\Windows Kits\10\lib\`).

### Capability exclusions

Several capabilities are not yet implemented on Windows. Until they land, exclude them in your app's `lune.yml`, otherwise the runtime raises `NotImplementedError`:

```yaml
capabilities:
  exclude:
    - file_watch      # planned: ReadDirectoryChangesW
    - file_drop
    - drag_out
    - context_menu
    - deep_link
    - filesystem      # partial
    - screen          # limited
    - windows         # multi-window not fully supported
```

## Known Limitations

- **WebView2 Runtime**: Developers and end-users need the WebView2 runtime installed on Windows 10 and earlier (Windows 11+ includes it).
- **Crystal 1.21.0**: Once released, the stdlib patch in Step 3 becomes unnecessary. Upgrade Crystal and remove the manual fix.
- **Running Specs**: `crystal spec` fails with the same `LibC::PidT` error. Until Crystal 1.21+, type-checking with `--no-codegen` is the workaround used in CI.
- **Isolated-context concurrency**: On Windows the webview runs inside `Fiber::ExecutionContext::Isolated` so it can own its thread (Win32 message-loop requirement). Bindings invoked from the webview thread cannot use `Future`, `spawn`, or `Channel#receive` — they raise `Binding execution failed: Concurrency is disabled in isolated contexts`. Known affected calls in the demo: `Clipboard.read`, `System.loadScreen`.
- **Unimplemented capabilities**: `file_watch`, `file_drop`, `drag_out`, `context_menu`, `deep_link`, and parts of `filesystem`/`screen`/`windows` are not yet wired up on Windows. Exclude them in `lune.yml` (see Step 6) until they're implemented.

## Troubleshooting

### `CPATH is not set`

If you get compilation errors about missing `WebView2.h`:

```cmd
REM Check CPATH
echo %CPATH%

REM Set it if missing (from x64 Native Tools Command Prompt)
set CPATH=C:\temp\webview2\Microsoft.Web.WebView2.1.0.3967.48\build\native\include
```

### Build Fails: `Cannot locate the .lib files for the following libraries: sqlite3, webview`

Ensure both Step 4a (sqlite3.lib creation) and Step 4b (webview build) are complete, and the `LIB` environment variable includes both paths:

```cmd
echo %LIB%
REM Should contain: C:\sqlite3;C:\Users\aris\code\lune\lib\webview\ext
```

If missing, re-run the `set LIB=...` command in Step 5 before building.

### Build Fails: `Cannot open include file: 'WebView2.h'`

The CPATH environment variable is not set correctly. See the `CPATH is not set` section above, or verify the WebView2 NuGet package was downloaded in Step 1.

## References

- [Lune README](README.md) — Platform support and quick start
- [Webview Library](lib/webview/README.md) — Raw webview bindings
- [Changelog v0.11.0](CHANGELOG.md) — Windows port details
- [Crystal Language](https://crystal-lang.org) — Language docs
