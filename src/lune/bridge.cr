require "json"

module Lune
  class Bridge
    getter all_bindings : Hash(String, BindingDef)

    def initialize(@wv : WebviewLike)
      @closed = Atomic(Bool).new(false)
      @all_bindings = {} of String => BindingDef
    end

    def close!
      @closed.set(true)
    end

    # -----------------------------------
    # Sync bindings
    # -----------------------------------
    def register_bindings(bindings : Array(BindingDef))
      bindings.each do |binding|
        register_binding(binding)
      end
    end

    # Fix: ensure the block passed to bind_deferred returns Nil
    def register_binding(binding : BindingDef)
      full_name = Lune.binding_id(binding.namespace, binding.name)
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
      wv = @wv
      wv.dispatch { wv.eval(js) }
    end

    # -----------------------------------
    # Internal dispatch
    # -----------------------------------

    private def execute_binding(
      binding : BindingDef,
      wv : WebviewLike,
      seq : String,
      args : Array(JSON::Any),
    )
      if binding.async
        spawn do
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
      wv : WebviewLike,
      seq : String,
      closed : (-> Bool)? = nil,
      &block : -> JSON::Any
    )
      result = block.call
      return if closed.try(&.call)
      wv.dispatch { wv.resolve(seq, 0, result.to_json) }
    rescue ex
      Lune.logger.error { "Binding execution failed: #{ex.message}" }
      Lune.logger.debug(exception: ex) { "Binding execution failed (stacktrace)" }
      return if closed.try(&.call)
      wv.dispatch { wv.resolve(seq, 1, {error: ex.message}.to_json) }
    end
  end
end
