require "json"

module Lune
  class Bridge
    include Bindable

    def initialize(@wv : WebviewLike)
      @closed = Atomic(Bool).new(false)
      @names = [] of String
      @seen = Set(String).new
    end

    def binding_names : Array(String)
      @names.dup
    end

    def close!
      @closed.set(true)
    end

    # -----------------------------------
    # Sync binding
    # -----------------------------------

    def bind(name : String, &block : Array(JSON::Any) -> JSON::Any)
      @names << name unless @seen.includes?(name)
      @seen << name
      wv = @wv

      @wv.bind_deferred(name) do |seq, args|
        dispatch_result(wv, seq, closed: -> { @closed.get }) do
          block.call(args)
        end
      end
    end

    # -----------------------------------
    # Async binding
    # -----------------------------------

    def bind_async(name : String, &block : Array(JSON::Any) -> JSON::Any)
      @names << name unless @seen.includes?(name)
      @seen << name
      wv = @wv

      @wv.bind_deferred(name) do |seq, args|
        spawn do
          dispatch_result(wv, seq, closed: -> { @closed.get }) do
            block.call(args)
          end
        end
      end
    end

    # -----------------------------------
    # Runtime helpers
    # -----------------------------------

    def eval(js : String)
      @wv.eval(js)
    end

    # -----------------------------------
    # Internal dispatch
    # -----------------------------------

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
