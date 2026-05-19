#!/bin/sh
# Patches lib/webview for macOS 26+ compatibility and rebuilds webview.o.
#
# On macOS 26+, nextEventMatchingMask: enforces the OS main thread strictly.
# Crystal's preview_mt fiber pool parks Thread 0 and runs the app (including
# NSApp) on a worker thread, so deplete_run_loop_event_queue() in the webview
# destructor crashes with std::terminate. The fix skips the drain when not on
# the OS main thread — safe because the window is already closed at that point.
#
# This script is idempotent: a second run is a no-op.
# Usage: sh ext/patches/patch_webview.sh [path/to/lib/webview]

WEBVIEW_DIR="${1:-lib/webview}"
HEADER="$WEBVIEW_DIR/ext/webview.h"
CC_FILE="$WEBVIEW_DIR/ext/webview.cc"
OBJ_FILE="$WEBVIEW_DIR/ext/webview.o"

if [ ! -f "$HEADER" ]; then
    echo "  [lune] $HEADER not found, skipping patch"
    exit 0
fi

# Already patched?
if grep -q "isMainThread" "$HEADER" 2>/dev/null; then
    exit 0
fi

echo "  [lune] Patching $HEADER for macOS 26+ main-thread safety..."

# Insert the isMainThread guard into the Cocoa deplete_run_loop_event_queue.
# The Cocoa version is uniquely identified by starting with objc::autoreleasepool.
perl -i -0777 -pe '
s|(  void deplete_run_loop_event_queue\(\) \{\n)(    objc::autoreleasepool)|${1}    if (!objc::msg_send<bool>("NSThread"_cls, "isMainThread"_sel)) { return; }\n${2}|g
' "$HEADER"

if ! grep -q "isMainThread" "$HEADER" 2>/dev/null; then
    echo "  [lune] WARNING: patch did not apply (pattern not found), skipping recompile"
    exit 0
fi

echo "  [lune] Recompiling $CC_FILE -> $OBJ_FILE..."

# Replicate the flags from lib/webview/Makefile
(cd "$WEBVIEW_DIR" && \
    ${CXX:-c++} -c ext/webview.cc -o ext/webview.o \
        -std=c++14 \
        -DWEBVIEW_COCOA=1 \
        -DWEBVIEW_BUILD_SHARED=1 \
        -DOBJC_OLD_DISPATCH_PROTOTYPES=1) \
    || { echo "  [lune] WARNING: recompile failed — webview.o may be stale"; exit 0; }

echo "  [lune] webview patched and rebuilt."
