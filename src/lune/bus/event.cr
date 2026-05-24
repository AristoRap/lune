module Lune
  # Crystal ↔ JS event bus. Subscribers (registered via `#on` / `#once`) fire on
  # `#dispatch`; `#emit` pushes a Crystal-side event into every connected
  # webview via `__lune.crystalEmit`.
  class Event
    include Subscribable

    # Cap on pending emits while waiting for the JS side to come up. Cold-start
    # bursts (e.g. a single deep_link) are tiny; the bound exists so a plugin
    # emitting in a loop pre-ready can't grow the queue unbounded.
    PENDING_MAX = 64

    def initialize(@bridge_fn : -> Bridge?, @extra_bridges : Array(Bridge))
      @once_handlers = {} of String => Array(Proc(JSON::Any, Nil))
      @ready = false
      @pending = Deque({String, String}).new
      @lock = Mutex.new
    end

    def emit(event : String, data = nil) : Nil
      json = data.nil? ? "null" : data.to_json
      dropped = false
      @lock.synchronize do
        if @ready
          dispatch_now(event, json)
        else
          @pending << {event, json}
          if @pending.size > PENDING_MAX
            @pending.shift
            dropped = true
          end
        end
      end
      if dropped
        Lune.logger.warn { "Event queue overflow (cap #{PENDING_MAX}); dropped oldest pending event while waiting for bridge ready" }
      end
    end

    # Signals that the JS bridge surface (`window.__lune.crystalEmit`) is
    # installed. Flushes any emits that arrived before the webview finished
    # loading. Idempotent: calls after the first do nothing.
    def mark_ready : Nil
      @lock.synchronize do
        return if @ready
        @ready = true
        @pending.each { |(event, json)| dispatch_now(event, json) }
        @pending.clear
      end
    end

    private def dispatch_now(event : String, json : String) : Nil
      return unless (b = @bridge_fn.call)
      bm = Lune::Plugin::BRIDGE_MARKER
      js = "if(window.#{bm}&&typeof window.#{bm}.crystalEmit==='function')window.#{bm}.crystalEmit(#{event.inspect},#{json})"
      b.dispatch_eval(js)
      @extra_bridges.each(&.dispatch_eval(js))
    end

    def once(event : String, &block : JSON::Any -> Nil) : Nil
      (@once_handlers[event] ||= [] of Proc(JSON::Any, Nil)) << block
    end

    def off(event : String) : Nil
      super
      @once_handlers.delete(event)
    end

    def dispatch(event : String, data : JSON::Any) : Nil
      super
      @once_handlers.delete(event).try(&.each(&.call(data)))
    end
  end
end
