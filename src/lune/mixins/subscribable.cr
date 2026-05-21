module Lune
  # Shared subscribe/dispatch surface for JSON-payload event buses.
  # Storage lives in the including class so each bus has its own table.
  module Subscribable
    macro included
      @handlers = {} of String => Array(Proc(JSON::Any, Nil))
    end

    def on(name : String, &block : JSON::Any -> Nil)
      (@handlers[name] ||= [] of Proc(JSON::Any, Nil)) << block
    end

    def off(name : String)
      @handlers.delete(name)
    end

    def dispatch(name : String, data : JSON::Any)
      @handlers[name]?.try(&.each(&.call(data)))
    end
  end
end
