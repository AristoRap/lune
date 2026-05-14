require "webview"
require "json"
require "set"

module Lune
  module WebviewLike
    abstract def bind_deferred(name : String, &block : String, Array(JSON::Any) -> Nil)
    abstract def dispatch(&f : ->)
    abstract def resolve(seq : String, status : Int32, result : String)
    abstract def eval(js : String)
  end
end

# Reopen Webview::Webview to add deferred (async) bind support.
# Kept here rather than in lib/ so the vendored dependency is never modified.
module Webview
  class Webview
    include ::Lune::WebviewLike

    private record DeferredCtx, w : LibWebView::T, cb : Proc(String, Array(JSON::Any), Nil)

    # Boxed closures are stored here so the GC never collects them.
    # Growth is bounded by the number of distinct bindings registered, which
    # is fixed at startup for typical apps.
    @@deferred_boxes = [] of Pointer(Void)

    # Registers a JS-callable function but does NOT auto-call webview_return.
    # The block receives (seq, args). Call resolve(seq, ...) whenever ready.
    def bind_deferred(name : String, &block : String, Array(JSON::Any) -> Nil)
      ctx = DeferredCtx.new(@w, block)
      boxed = Box.box(ctx)

      check_error(LibWebView.bind(@w, name, ->(id, req, data) {
        seq = String.new(id)
        cb_ctx = Box(DeferredCtx).unbox(data)

        # JSON.parse can raise if the webview sends malformed input.
        # We must not let an exception escape a C callback — catch it here
        # and return an error response so the JS Promise rejects cleanly.
        args = begin
          JSON.parse(String.new(req)).as_a
        rescue ex
          err = {error: "Lune: malformed binding payload: #{ex.message}"}.to_json
          LibWebView.webview_return(cb_ctx.w, seq, 1, err)
          return
        end

        cb_ctx.cb.call(seq, args)
      }, boxed))

      @@deferred_boxes << boxed
    end

    # Send a response to a pending JS promise from bind_deferred.
    # status: 0 = success, non-zero = error. result must be valid JSON.
    def resolve(seq : String, status : Int32, result : String)
      LibWebView.webview_return(@w, seq, status, result)
    end
  end
end
