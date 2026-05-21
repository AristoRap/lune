module Lune
  module Capabilities
    class FileWatch < Lune::Capability
      include Capability::BindPhase
      include Capability::Lifecycle

      # macOS (kqueue) + Linux (inotify). Win32 needs `ReadDirectoryChangesW`
      # plumbing (see ROADMAP).
      DESCRIPTOR = Descriptor.new(id: :file_watch, label: "FileWatch", deps: [:events], platforms: [:darwin, :linux])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def binding_namespace : String
        "FileWatch"
      end

      @watcher = Lune::Native::FileWatch.new
      @debounce = 50.milliseconds

      def setup(ctx : SetupCtx) : Nil
        @debounce = ctx.options.file_watch.debounce
      end

      def install(ctx : BindCtx) : Nil
        app = ctx.app
        @watcher.start(app, @debounce)

        watcher = @watcher
        ctx.define("watch",
          args: ["String"],
          arg_names: ["path"],
        ) do |args|
          watcher.add_watch(args[0].as_s)
          JSON::Any.new(nil)
        end

        ctx.define("unwatch",
          args: ["String"],
          arg_names: ["path"],
        ) do |args|
          watcher.remove_watch(args[0].as_s)
          JSON::Any.new(nil)
        end
      end

      def shutdown : Nil
        @watcher.stop
      end

      def js_helpers : String
        bm = BRIDGE_MARKER
        <<-JS
          on(cb)   { window.#{bm}.on("file_watch", cb, -1); },
          once(cb) { window.#{bm}.on("file_watch", cb, 1); },
          off(cb)  { window.#{bm}.off("file_watch", cb); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          on(cb: (event: { path: string; kind: "modified" | "created" | "deleted" | "renamed" }) => void): void;
          once(cb: (event: { path: string; kind: "modified" | "created" | "deleted" | "renamed" }) => void): void;
          off(cb?: (event: { path: string; kind: "modified" | "created" | "deleted" | "renamed" }) => void): void;
        DTS
      end

      # On unsupported platforms `watch`/`unwatch` reject loudly (they're real
      # API calls users await), while the event-subscription helpers (`on`/
      # `once`/`off`) silently no-op + one-time console.warn — they return void
      # in the live API, so throwing here would crash app init for code that
      # wires subscriptions up front.
      def unavailable_js_stub(platform : Symbol) : String?
        ns = binding_namespace
        msg = ->(m : String) { "#{ns}.#{m} is not available on #{platform}" }
        <<-JS
        export const #{ns} = (function(){
          var _warned = false;
          var _warn = function(m) { if (!_warned) { _warned = true; console.warn(m + " — subscription will not fire."); } };
          return {
            watch(path)   { return Promise.reject(new LuneError("UNAVAILABLE_ON_PLATFORM", #{msg.call("watch").inspect})); },
            unwatch(path) { return Promise.reject(new LuneError("UNAVAILABLE_ON_PLATFORM", #{msg.call("unwatch").inspect})); },
            on(cb)        { _warn(#{msg.call("on").inspect}); },
            once(cb)      { _warn(#{msg.call("once").inspect}); },
            off(cb)       { /* noop */ },
          };
        })();
        JS
      end

      def unavailable_dts_stub : String?
        ns = binding_namespace
        <<-DTS
        export interface #{ns} {
          watch(path: string): Promise<void>;
          unwatch(path: string): Promise<void>;
          on(cb: (event: { path: string; kind: "modified" | "created" | "deleted" | "renamed" }) => void): void;
          once(cb: (event: { path: string; kind: "modified" | "created" | "deleted" | "renamed" }) => void): void;
          off(cb?: (event: { path: string; kind: "modified" | "created" | "deleted" | "renamed" }) => void): void;
        }
        DTS
      end
    end
  end
end
