require "json"

module Lune
  module Runtime
    module Bindings
      class Dialogs
        include Lune::Installable

        def install(app : Lune::App)
          open_file(app)
          open_dir(app)
          open_files(app)
          save_file(app)
          message_info(app)
          message_warning(app)
          message_error(app)
          message_question(app)
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

        private def open_dir(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.openDir",
            args: ["String"],
            return_type: "String",
            callback: ->(args : Array(JSON::Any)) {
              path = Lune::Native::Dialog.open_dir(args[0].as_s)
              JSON::Any.new(path || "")
            },
            arg_names: ["prompt"],
          ))
        end

        private def open_files(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.openFiles",
            args: ["String"],
            return_type: "Array",
            ts_return_type: "Promise<string[]>",
            callback: ->(args : Array(JSON::Any)) {
              paths = Lune::Native::Dialog.open_files(args[0].as_s)
              JSON.parse(paths.to_json)
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
        private def message_info(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.messageInfo",
            args: ["String", "String"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              Lune::Native::Dialog.message(0, args[0].as_s, args[1].as_s)
              JSON::Any.new(nil)
            },
            arg_names: ["title", "message"],
          ))
        end

        private def message_warning(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.messageWarning",
            args: ["String", "String"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              Lune::Native::Dialog.message(1, args[0].as_s, args[1].as_s)
              JSON::Any.new(nil)
            },
            arg_names: ["title", "message"],
          ))
        end

        private def message_error(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.messageError",
            args: ["String", "String"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              Lune::Native::Dialog.message(2, args[0].as_s, args[1].as_s)
              JSON::Any.new(nil)
            },
            arg_names: ["title", "message"],
          ))
        end

        private def message_question(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.messageQuestion",
            args: ["String", "String"],
            return_type: "String",
            callback: ->(args : Array(JSON::Any)) {
              result = Lune::Native::Dialog.message(3, args[0].as_s, args[1].as_s)
              JSON::Any.new(result)
            },
            arg_names: ["title", "message"],
          ))
        end
      end
    end
  end
end
