require "json"
require "vow/registry"

module Lune
  class Bridge
    getter all_bindings : Hash(String, Binding)

    @async_pool : Fiber::ExecutionContext::Parallel? = nil
    @wv : Webview::WebviewLike

    def initialize(@wv : Webview::WebviewLike, @registry : ::Vow::Registry)
      @closed = Atomic(Bool).new(false)
      @all_bindings = {} of String => Binding
    end

    def close!
      @closed.set(true)
    end

    # -----------------------------------
    # Sync bindings
    # -----------------------------------
    def register_bindings(bindings : Array(Binding))
      bindings.each do |binding|
        register_binding(binding)
      end
    end

    # Fix: ensure the block passed to bind_deferred returns Nil
    def register_binding(binding : Binding)
      full_name = binding.id
      @all_bindings[full_name] = binding
      wv = @wv

      @wv.bind_deferred(full_name) do |seq, args|
        execute_binding(binding, wv, seq, args)
        nil
      end
    end

    # -----------------------------------
    # Runtime helpers
    # -----------------------------------

    def eval(js : String)
      @wv.eval(js)
    end

    def dispatch_eval(js : String)
      return if @closed.get
      wv = @wv
      # Re-check `@closed` inside the queued block: between enqueue and drain the
      # bridge may be closed and the webview engine torn down. On Win32 the
      # engine's destructor still drains pending dispatches via
      # `deplete_run_loop_event_queue`, so a stale `eval` here calls into a
      # half-destroyed engine and SEGVs. `@closed` is read through `self` (Crystal
      # `Atomic` is a struct — a local copy wouldn't see the bridge's flag flip).
      wv.dispatch do
        next if @closed.get
        wv.eval(js)
      end
    end

    # -----------------------------------
    # Internal dispatch
    # -----------------------------------

    private def execute_binding(
      binding : Binding,
      wv : Webview::WebviewLike,
      seq : String,
      args : Array(JSON::Any),
    )
      # The named-args object rides through the webview's positional array as a
      # single element; hand its JSON straight to the registry (a zero-arg call
      # sends `{}`). `dispatch` decodes, invokes, and JSON-encodes the result.
      raw = args.empty? ? "{}" : args[0].to_json
      # Per-call context — injected only into bindings that declare a leading
      # `Lune::WindowContext` param; ignored by every other binding.
      ctx = WindowContext.new(seq, wv)
      if binding.async
        pool = @async_pool ||= Fiber::ExecutionContext::Parallel.new("lune-async", System.cpu_count)
        pool.spawn do
          dispatch_result(wv, seq, closed: -> { @closed.get }) do
            @registry.dispatch(binding.id, raw, ctx)
          end
        end
      else
        dispatch_result(wv, seq, closed: -> { @closed.get }) do
          @registry.dispatch(binding.id, raw, ctx)
        end
      end
    end

    private def dispatch_result(
      wv : Webview::WebviewLike,
      seq : String,
      closed : (-> Bool)? = nil,
      &block : -> String
    )
      # `Vow::Registry#dispatch` already JSON-encodes the result here — OUTSIDE
      # the Cocoa `dispatch_async` callback below — so an encoding error unwinds
      # on a plain Crystal fiber rather than inside the autorelease-pool callback
      # (a SIGSEGV in `objc_autoreleasePoolPop` was observed once on that path).
      payload = block.call
      return if closed.try(&.call)
      wv.dispatch { safe_resolve(wv, seq, 0, payload, closed) }
    rescue ex
      Lune.logger.error { "Binding execution failed: #{ex.message}" }
      Lune.logger.debug(exception: ex) { "Binding execution failed (stacktrace)" }
      code = ex.as?(::Vow::Error).try(&.code) || ex.as?(Lune::Error).try(&.code) || "error"
      hint = ex.as?(::Vow::Error).try(&.hint) || ex.as?(Lune::Error).try(&.hint)
      payload = error_envelope(code, ex.message, hint)
      return if closed.try(&.call)
      wv.dispatch { safe_resolve(wv, seq, 1, payload, closed) }
    end

    # Resolve inside a rescue barrier. Any Crystal exception that unwinds
    # through the dispatched-block frame can corrupt Cocoa's autorelease-pool
    # stack — we've seen one SIGSEGV in `objc_autoreleasePoolPop` during the
    # error-reply path. Swallow everything here; the call has already produced
    # a payload string, so there's nothing left to surface.
    private def safe_resolve(wv : Webview::WebviewLike, seq : String, status : Int32, payload : String, closed : (-> Bool)?) : Nil
      return if closed.try(&.call)
      wv.resolve(seq, status, payload)
    rescue ex
      Lune.logger.error { "Bridge reply failed for seq #{seq}: #{ex.message}" } rescue nil
    end

    # Same isolation contract as `safe_resolve` but for the JSON encoding
    # itself — if `ex.message` has a weird encoding or anything along the
    # `to_json` chain raises, fall back to a hand-built envelope so the JS
    # side at least sees a recognisable error shape.
    private def error_envelope(code : String, message : String?, hint : String? = nil) : String
      {code: code, error: message, hint: hint}.to_json
    rescue ex
      Lune.logger.error { "Failed to encode error envelope: #{ex.message}" } rescue nil
      %({"code":"error","error":"<encoding failed>"})
    end
  end
end
