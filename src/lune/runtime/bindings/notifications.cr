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
          app.bind(
            namespace: "runtime",
            method: "__lune.notify",
            args: ["String", "String"],
            return_type: "Nil",
            async: false,
            runtime: true
          ) do |args|
            Lune::Native::Notify.show(args[0].as_s, args[1].as_s)
            JSON::Any.new(nil)
          end
        end
      end
    end
  end
end
