module Lune
  module Capabilities
    class DragOut < Lune::Capability
      include Capability::Bindable

      DESCRIPTOR = Descriptor.new(id: :drag_out, label: "DragOut")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @handle : Void* = Pointer(Void).null

      def setup(ctx : SetupCtx) : Nil
        @handle = ctx.handle
      end

      def install(ctx : BindCtx) : Nil
        h = @handle
        ctx.register(Definition.new(
          name: "#{name}.start",
          args: ["String"],
          return_type: "Nil",
          callback: ->(args : Array(JSON::Any)) {
            Lune::Native::Window.start_drag_out(h, JSON.parse(args[0].as_s).as_a.map(&.as_s))
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))
      end

      def js_helpers : String
        bridge_id = "#{BRIDGE_MARKER}.#{name}.start"
        <<-JS
          start(paths) { return __lune.call(#{bridge_id.inspect}, JSON.stringify(paths || [])); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          start(paths: string[]): Promise<void>;
        DTS
      end
    end
  end
end
