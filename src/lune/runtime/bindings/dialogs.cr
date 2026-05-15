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
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.openFile",
            args: ["String"],
            return_type: "String",
            callback: ->(args : Array(JSON::Any)) {
              path = Lune::Native::Dialog.open_file(args[0].as_s)
              JSON::Any.new(path || "")
            },
            arg_names: ["prompt"],
          ))
        end

        private def save_file(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.saveFile",
            args: ["String", "String"],
            return_type: "String",
            callback: ->(args : Array(JSON::Any)) {
              path = Lune::Native::Dialog.save_file(args[0].as_s, args[1].as_s)
              JSON::Any.new(path || "")
            },
            arg_names: ["prompt", "filename"],
          ))
        end
      end
    end
  end
end
