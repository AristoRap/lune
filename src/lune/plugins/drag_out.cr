module Lune
  module Plugins
    class DragOut < Lune::Plugin
      include Lune::Bindable

      # macOS-only. The Win32 / X11 drag-out flows require native window
      # subclassing and pasteboard plumbing we don't have today — see ROADMAP.
      DESCRIPTOR = Descriptor.new(id: :drag_out, label: "DragOut", platforms: [:darwin])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @handle : Void* = Pointer(Void).null

      def setup(ctx : SetupCtx) : Nil
        @handle = ctx.handle
      end

      @[Lune::Bind]
      def start(paths : Array(String)) : Nil
        Lune::Native::Window.start_drag_out(@handle, paths)
      end

      def unavailable_js_stub(platform : Symbol) : String?
        ns = binding_namespace.gsub("::", ".")
        msg = "#{ns}.start is not available on #{platform}"
        <<-JS
          start(args) { return Promise.reject(new LuneError("UNAVAILABLE_ON_PLATFORM", #{msg.inspect})); },
        JS
      end

      def unavailable_dts_stub : String?
        <<-DTS
          start(args: { paths: string[] }): Promise<void>;
        DTS
      end
    end
  end
end
