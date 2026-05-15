require "json"

module Lune
  module Runtime
    module Bindings
      class Notifications
        include Lune::Installable

        def install(app : Lune::App)
          notify(app)
        end

        private def notify(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.notify",
            args: ["String", "String"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              Lune::Native::Notify.show(args[0].as_s, args[1].as_s)
              JSON::Any.new(nil)
            },
            arg_names: ["title", "body"],
          ))
        end
      end
    end
  end
end
