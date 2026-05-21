module Lune
  # Crystal ↔ JS event bus. Subscribers (registered via `#on` / `#once`) fire on
  # `#dispatch`; `#emit` pushes a Crystal-side event into every connected
  # webview via `__lune.crystalEmit`.
  class Events
    include Subscribable

    def initialize(@bridge_fn : -> Bridge?, @extra_bridges : Array(Bridge))
      @once_handlers = {} of String => Array(Proc(JSON::Any, Nil))
    end

    def emit(event : String, data = nil)
      return unless (b = @bridge_fn.call)
      json = data.nil? ? "null" : data.to_json
      bm = Lune::Capability::BRIDGE_MARKER
      b.dispatch_eval("if(window.#{bm}&&typeof window.#{bm}.crystalEmit==='function')window.#{bm}.crystalEmit(#{event.inspect},#{json})")
      @extra_bridges.each(&.dispatch_eval("if(window.#{bm}&&typeof window.#{bm}.crystalEmit==='function')window.#{bm}.crystalEmit(#{event.inspect},#{json})"))
    end

    def once(event : String, &block : JSON::Any -> Nil)
      (@once_handlers[event] ||= [] of Proc(JSON::Any, Nil)) << block
    end

    def off(event : String)
      super
      @once_handlers.delete(event)
    end

    def dispatch(event : String, data : JSON::Any)
      super
      @once_handlers.delete(event).try(&.each(&.call(data)))
    end
  end
end
