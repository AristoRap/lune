module Lune
  module Plugins
    class FileWatch < Lune::Plugin
      include Lune::Bindable
      include Plugin::Lifecycle

      # macOS (kqueue) + Linux (inotify). Win32 needs `ReadDirectoryChangesW`
      # plumbing (see ROADMAP).
      DESCRIPTOR = Descriptor.new(id: :file_watch, label: "FileWatch", deps: [:events], platforms: [:darwin, :linux])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @watcher = Lune::Native::FileWatch.new
      @debounce = 50.milliseconds
      @last_fired = {} of String => Time::Instant

      def setup(ctx : SetupCtx) : Nil
        @debounce = ctx.options.file_watch.debounce
      end

      # Hook the macro-generated install to also kick off the native watcher
      # pump, which delivers `(path, kind)` callbacks into `app.events`.
      def install(app : Lune::App) : Nil
        previous_def
        debounce = @debounce
        last_fired = @last_fired
        @watcher.start do |path, kind|
          now = Time.instant
          next if (prev = last_fired[path]?) && (now - prev) < debounce
          last_fired[path] = now
          app.events.emit("file_watch", {"path" => path, "kind" => kind})
        end
      end

      @[Lune::Bind]
      def watch(path : String) : Nil
        @watcher.add_watch(path)
      end

      @[Lune::Bind]
      def unwatch(path : String) : Nil
        @watcher.remove_watch(path)
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
      # `once`/`off`) silently skip + one-time console.warn — they return void
      # in the live API, so throwing here would crash app init for code that
      # wires subscriptions up front.
      def unavailable_js_stub(platform : Symbol) : String?
        ns = binding_namespace.gsub("::", ".")
        msg = ->(m : String) { "#{ns}.#{m} is not available on #{platform}" }
        <<-JS
          _warned: false,
          _warn(m) { if (!this._warned) { this._warned = true; console.warn(m + " — subscription will not fire."); } },
          watch(path)   { return Promise.reject(new LuneError("UNAVAILABLE_ON_PLATFORM", #{msg.call("watch").inspect})); },
          unwatch(path) { return Promise.reject(new LuneError("UNAVAILABLE_ON_PLATFORM", #{msg.call("unwatch").inspect})); },
          on(cb)        { this._warn(#{msg.call("on").inspect}); },
          once(cb)      { this._warn(#{msg.call("once").inspect}); },
          off(cb)       { },
        JS
      end

      def unavailable_dts_stub : String?
        <<-DTS
          watch(path: string): Promise<void>;
          unwatch(path: string): Promise<void>;
          on(cb: (event: { path: string; kind: "modified" | "created" | "deleted" | "renamed" }) => void): void;
          once(cb: (event: { path: string; kind: "modified" | "created" | "deleted" | "renamed" }) => void): void;
          off(cb?: (event: { path: string; kind: "modified" | "created" | "deleted" | "renamed" }) => void): void;
        DTS
      end
    end
  end
end
