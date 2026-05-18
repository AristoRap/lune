module Lune
  module Capabilities
    class Notifications < Lune::Capability
      def name : String
        "notifications"
      end


      def install(app : Lune::App)
        app.register(Definition.new(
          name: "#{name}.notify",
          args: ["String", "String"],
          return_type: "Nil",
          arg_names: ["title", "body"],
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Notify.show(args[0].as_s, args[1].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))
      end
    end
  end
end
