module Lune
  module Capabilities
    class Dialogs < Lune::Capability
      include Capability::BindPhase

      DESCRIPTOR = Descriptor.new(id: :dialogs, label: "Dialogs")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def install(ctx : BindCtx) : Nil
        ctx.define("open_file",
          args: ["String"],
          return_type: "String",
          arg_names: ["prompt"],
        ) do |args|
          JSON::Any.new(Lune::Native::Dialogs.open_file(args[0].as_s) || "")
        end

        ctx.define("open_dir",
          args: ["String"],
          return_type: "String",
          arg_names: ["prompt"],
        ) do |args|
          JSON::Any.new(Lune::Native::Dialogs.open_dir(args[0].as_s) || "")
        end

        ctx.define("open_files",
          args: ["String"],
          return_type: "Array",
          arg_names: ["prompt"],
          ts_return_type: "Promise<string[]>",
        ) do |args|
          JSON.parse(Lune::Native::Dialogs.open_files(args[0].as_s).to_json)
        end

        ctx.define("save_file",
          args: ["String", "String"],
          return_type: "String",
          arg_names: ["prompt", "filename"],
        ) do |args|
          JSON::Any.new(Lune::Native::Dialogs.save_file(args[0].as_s, args[1].as_s) || "")
        end

        [
          {"info", 0, false},
          {"warning", 1, false},
          {"error", 2, false},
          {"question", 3, true},
        ].each do |(variant, code, returns_value)|
          return_type = returns_value ? "String" : "Nil"
          ctx.define("message_#{variant}",
            args: ["String", "String"],
            return_type: return_type,
            arg_names: ["title", "message"],
          ) do |args|
            result = Lune::Native::Dialogs.message(code, args[0].as_s, args[1].as_s)
            returns_value ? JSON::Any.new(result) : JSON::Any.new(nil)
          end
        end
      end
    end
  end
end
