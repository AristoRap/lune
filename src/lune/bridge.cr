require "json"

module Lune
  class Bridge
    getter all_bindings : Hash(String, Binding)

    @async_pool : Fiber::ExecutionContext::Parallel? = nil

    def initialize(@wv : Webview::WebviewLike)
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
      wv.dispatch { wv.eval(js) }
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
      if binding.async
        pool = @async_pool ||= Fiber::ExecutionContext::Parallel.new("lune-async", System.cpu_count)
        pool.spawn do
          dispatch_result(wv, seq, closed: -> { @closed.get }) do
            binding.callback.call(args)
          end
        end
      else
        dispatch_result(wv, seq, closed: -> { @closed.get }) do
          binding.callback.call(args)
        end
      end
    end

    private def dispatch_result(
      wv : Webview::WebviewLike,
      seq : String,
      closed : (-> Bool)? = nil,
      &block : -> JSON::Any
    )
      result = block.call
      # Serialize OUTSIDE the dispatched block: if `to_json` raises (cyclic
      # refs, encoding quirks), we'd rather have it unwind here — on a plain
      # Crystal fiber — than inside the Cocoa `dispatch_async` callback
      # where it can corrupt the autorelease-pool stack (signal 11 in
      # `objc_autoreleasePoolPop`, observed once on the error path).
      payload = result.to_json
      return if closed.try(&.call)
      wv.dispatch { safe_resolve(wv, seq, 0, payload, closed) }
    rescue ex
      Lune.logger.error { "Binding execution failed: #{ex.message}" }
      Lune.logger.debug(exception: ex) { "Binding execution failed (stacktrace)" }
      code = ex.as?(Lune::Error).try(&.code) || "error"
      payload = error_envelope(code, ex.message)
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
    private def error_envelope(code : String, message : String?) : String
      {code: code, error: message}.to_json
    rescue ex
      Lune.logger.error { "Failed to encode error envelope: #{ex.message}" } rescue nil
      %({"code":"error","error":"<encoding failed>"})
    end
  end
end
