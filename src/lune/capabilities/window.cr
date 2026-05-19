module Lune
  module Capabilities
    class Window < Lune::Capability
      include Capability::Bindable

      DESCRIPTOR = Descriptor.new(id: :window, label: "Window")

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
          name: "#{name}.minimize",
          args: [] of String,
          return_type: "Nil",
          callback: ->(_args : Array(JSON::Any)) { Lune::Native::Window.minimize(h); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.maximize",
          args: [] of String,
          return_type: "Nil",
          callback: ->(_args : Array(JSON::Any)) { Lune::Native::Window.maximize(h); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.set_title",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["title"],
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Window.set_title(h, args[0].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.set_size",
          args: ["Int32", "Int32"],
          return_type: "Nil",
          arg_names: ["width", "height"],
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Window.set_size(h, args[0].as_i, args[1].as_i); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.center",
          args: [] of String,
          return_type: "Nil",
          callback: ->(_args : Array(JSON::Any)) { Lune::Native::Window.center(h); JSON::Any.new(nil) },
        ).binding(binding_namespace))
      end
    end
  end
end
