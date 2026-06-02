require "vow/context"

module Lune
  # Per-call request context for a webview→Crystal binding: which webview made
  # the call and the call's sequence id. A binding opts in by declaring a
  # leading `ctx : Lune::WindowContext` parameter — the bridge injects it at
  # dispatch, and `Bindable` keeps it out of the wire args, the manifest, and
  # the generated client signature (same opt-in rule as `Vow::Context`).
  # Bindings that don't declare it are unaffected.
  class WindowContext < ::Vow::Context
    # The call's sequence id (the webview's reply correlation token).
    getter seq : String
    # The webview that made the call — identity, and a handle to `eval` back
    # into the calling window.
    getter webview : Webview::WebviewLike

    def initialize(@seq : String, @webview : Webview::WebviewLike)
    end

    # `Vow::Context` generic string-metadata accessor: only `"seq"` is defined.
    def [](key : String) : String?
      key == "seq" ? @seq : nil
    end
  end
end
