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
          arg_names: ["paths"],
          arg_transforms: ["JSON.stringify(paths || [])"] of String?,
          ts_args: ["string[]"] of String?,
          return_type: "Nil",
          callback: ->(args : Array(JSON::Any)) {
            Lune::Native::Window.start_drag_out(h, JSON.parse(args[0].as_s).as_a.map(&.as_s))
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))
      end
    end
  end
end
