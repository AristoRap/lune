module Lune
  module Capabilities
    class ContextMenu < Lune::Capability
      def initialize(@handle : Void*)
      end

      def name : String
        "context_menu"
      end

      def core? : Bool
        false
      end

      def install(app : Lune::App)
        h = @handle
        app.register(Definition.new(
          name: "#{name}.show",
          args: ["Float64", "Float64", "String"],
          return_type: "Nil",
          callback: ->(args : Array(JSON::Any)) {
            Lune::Native::Menu.show_context_menu(h, args[0].as_f.to_f32, args[1].as_f.to_f32, args[2].as_s) do |id|
              app.emit("context_menu", {"id" => id})
            end
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))
      end
    end
  end
end
