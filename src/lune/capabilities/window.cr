module Lune
  module Capabilities
    class Window < Lune::Capability
      include Capability::BindPhase

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

        [
          {"minimize", -> { Lune::Native::Window.minimize(h) }},
          {"maximize", -> { Lune::Native::Window.maximize(h) }},
          {"center", -> { Lune::Native::Window.center(h) }},
          {"hide", -> { Lune::Native::Window.hide(h) }},
          {"show", -> { Lune::Native::Window.show(h) }},
        ].each do |(method, action)|
          ctx.define(method) do |_args|
            action.call
            JSON::Any.new(nil)
          end
        end

        ctx.define("set_title",
          args: ["String"],
          arg_names: ["title"],
        ) do |args|
          Lune::Native::Window.set_title(h, args[0].as_s)
          JSON::Any.new(nil)
        end

        ctx.define("set_size",
          args: ["Int32", "Int32"],
          arg_names: ["width", "height"],
        ) do |args|
          Lune::Native::Window.set_size(h, args[0].as_i, args[1].as_i)
          JSON::Any.new(nil)
        end
      end
    end
  end
end
