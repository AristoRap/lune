module Lune
  module Capabilities
    class Dialogs < Lune::Capability
      include Capability::Bindable

      DESCRIPTOR = Descriptor.new(id: :dialogs, label: "Dialogs")
      def descriptor : Descriptor; DESCRIPTOR; end


      def install(app : App) : Nil
        install(BindCtx.new(app))
      end

      def install(ctx : BindCtx) : Nil
        ctx.register(Definition.new(
          name: "#{name}.open_file",
          args: ["String"],
          return_type: "String",
          arg_names: ["prompt"],
          callback: ->(args : Array(JSON::Any)) { JSON::Any.new(Lune::Native::Dialog.open_file(args[0].as_s) || "") },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.open_dir",
          args: ["String"],
          return_type: "String",
          arg_names: ["prompt"],
          callback: ->(args : Array(JSON::Any)) { JSON::Any.new(Lune::Native::Dialog.open_dir(args[0].as_s) || "") },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.open_files",
          args: ["String"],
          return_type: "Array",
          arg_names: ["prompt"],
          ts_return_type: "Promise<string[]>",
          callback: ->(args : Array(JSON::Any)) { JSON.parse(Lune::Native::Dialog.open_files(args[0].as_s).to_json) },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.save_file",
          args: ["String", "String"],
          return_type: "String",
          arg_names: ["prompt", "filename"],
          callback: ->(args : Array(JSON::Any)) { JSON::Any.new(Lune::Native::Dialog.save_file(args[0].as_s, args[1].as_s) || "") },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.message_info",
          args: ["String", "String"],
          return_type: "Nil",
          arg_names: ["title", "message"],
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Dialog.message(0, args[0].as_s, args[1].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.message_warning",
          args: ["String", "String"],
          return_type: "Nil",
          arg_names: ["title", "message"],
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Dialog.message(1, args[0].as_s, args[1].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.message_error",
          args: ["String", "String"],
          return_type: "Nil",
          arg_names: ["title", "message"],
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Dialog.message(2, args[0].as_s, args[1].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.message_question",
          args: ["String", "String"],
          return_type: "String",
          arg_names: ["title", "message"],
          callback: ->(args : Array(JSON::Any)) { JSON::Any.new(Lune::Native::Dialog.message(3, args[0].as_s, args[1].as_s)) },
        ).binding(binding_namespace))
      end
    end
  end
end
