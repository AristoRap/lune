module Lune
  module Capabilities
    class FileWatch < Lune::Capability
      include Capability::Bindable
      include Capability::Lifecycle

      DESCRIPTOR = Descriptor.new(id: :file_watch, label: "FileWatch", deps: [:event_bus])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def binding_namespace : String
        "FileWatch"
      end

      @watcher  = Lune::Native::FileWatch.new
      @debounce = 50.milliseconds

      def setup(ctx : SetupCtx) : Nil
        @debounce = ctx.options.file_watch.debounce
      end

      def install(ctx : BindCtx) : Nil
        app = ctx.app
        @watcher.start(app, @debounce)

        watcher = @watcher
        ctx.register(Definition.new(
          name: "#{name}.watch",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["path"],
          callback: ->(args : Array(JSON::Any)) {
            watcher.add_watch(args[0].as_s)
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.unwatch",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["path"],
          callback: ->(args : Array(JSON::Any)) {
            watcher.remove_watch(args[0].as_s)
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))
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
    end
  end
end
