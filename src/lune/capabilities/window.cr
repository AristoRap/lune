module Lune
  module Capabilities
    class Window < Lune::Capability
      def initialize(@handle : Void*)
      end

      def name : String
        "window"
      end

      def core? : Bool
        false
      end

      def install(app : Lune::App)
        h = @handle
        app.register(Definition.new(
          name: "#{name}.minimize",
          args: [] of String,
          return_type: "Nil",
          callback: ->(_args : Array(JSON::Any)) { Lune::Native::Window.minimize(h); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        app.register(Definition.new(
          name: "#{name}.maximize",
          args: [] of String,
          return_type: "Nil",
          callback: ->(_args : Array(JSON::Any)) { Lune::Native::Window.maximize(h); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        app.register(Definition.new(
          name: "#{name}.set_title",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["title"],
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Window.set_title(h, args[0].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        app.register(Definition.new(
          name: "#{name}.set_size",
          args: ["Int32", "Int32"],
          return_type: "Nil",
          arg_names: ["width", "height"],
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Window.set_size(h, args[0].as_i, args[1].as_i); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        app.register(Definition.new(
          name: "#{name}.center",
          args: [] of String,
          return_type: "Nil",
          callback: ->(_args : Array(JSON::Any)) { Lune::Native::Window.center(h); JSON::Any.new(nil) },
        ).binding(binding_namespace))
      end
    end
  end
end
