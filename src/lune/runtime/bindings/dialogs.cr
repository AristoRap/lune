require "json"

module Lune
  module Runtime
    module Bindings
      class Dialogs
        include Lune::Installable

        def install(app : Lune::App)
          open_file(app)
          save_file(app)
        end

        private def open_file(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.openFile",
            args: ["String"],
            return_type: "String",
            async: false,
            runtime: true
          ) do |args|
            path = Lune::Native::Dialog.open_file(args[0].as_s)
            JSON::Any.new(path || "")
          end
        end

        private def save_file(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.saveFile",
            args: ["String", "String"],
            return_type: "String",
            async: false,
            runtime: true
          ) do |args|
            path = Lune::Native::Dialog.save_file(args[0].as_s, args[1].as_s)
            JSON::Any.new(path || "")
          end
        end
      end
    end
  end
end
