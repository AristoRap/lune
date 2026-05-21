module Lune
  module Capabilities
    class DragOut < Lune::Capability
      include Capability::BindPhase

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

      def install(ctx : BindCtx) : Nil
        h = @handle
        ctx.define("start",
          args: ["String"],
          arg_names: ["paths"],
          arg_transforms: ["JSON.stringify(paths || [])"] of String?,
          ts_args: ["string[]"] of String?,
        ) do |args|
          Lune::Native::Window.start_drag_out(h, JSON.parse(args[0].as_s).as_a.map(&.as_s))
          JSON::Any.new(nil)
        end
      end

      def unavailable_js_stub(platform : Symbol) : String?
        ns = binding_namespace
        msg = "#{ns}.start is not available on #{platform}"
        <<-JS
        export const #{ns} = {
          start(paths) { return Promise.reject(new LuneError("UNAVAILABLE_ON_PLATFORM", #{msg.inspect})); },
        };
        JS
      end

      def unavailable_dts_stub : String?
        ns = binding_namespace
        <<-DTS
        export interface #{ns} {
          start(paths: string[]): Promise<void>;
        }
        DTS
      end
    end
  end
end
