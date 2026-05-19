module Lune
  module Capabilities
    class Filesystem < Lune::Capability
      include Capability::Bindable

      DESCRIPTOR = Descriptor.new(id: :filesystem, label: "Filesystem")

      def descriptor : Descriptor
        DESCRIPTOR
      end


      def install(ctx : BindCtx) : Nil
        ctx.register(Definition.new(
          name: "#{name}.home_dir",
          args: [] of String,
          return_type: "String",
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(Path.home.to_s) },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.temp_dir",
          args: [] of String,
          return_type: "String",
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(Dir.tempdir) },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.downloads_dir",
          args: [] of String,
          return_type: "String",
          callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(Path.home.join("Downloads").to_s) },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.app_data_dir",
          args: [] of String,
          return_type: "String",
          callback: ->(_args : Array(JSON::Any)) {
            path =
              {% if flag?(:darwin) %}
                Path.home.join("Library", "Application Support").to_s
              {% elsif flag?(:win32) %}
                ENV["APPDATA"]? || Path.home.to_s
              {% else %}
                ENV["XDG_DATA_HOME"]? || Path.home.join(".local", "share").to_s
              {% end %}
            JSON::Any.new(path)
          },
        ).binding(binding_namespace))
      end
    end
  end
end
