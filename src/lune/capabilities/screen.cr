module Lune
  module Capabilities
    class Screen < Lune::Capability
      def name : String
        "screen"
      end

      def core? : Bool
        false
      end

      def install(app : Lune::App)
        app.register(Definition.new(
          name: "#{name}.info",
          args: [] of String,
          return_type: "String",
          ts_return_type: "Promise<ScreenInfo>",
          callback: ->(_args : Array(JSON::Any)) {
            si = Lune::Native::Screen.info
            JSON::Any.new({
              "width"  => JSON::Any.new(si.width.to_i64),
              "height" => JSON::Any.new(si.height.to_i64),
              "scale"  => JSON::Any.new(si.scale),
            } of String => JSON::Any)
          },
        ).binding(binding_namespace))
      end
    end
  end
end
