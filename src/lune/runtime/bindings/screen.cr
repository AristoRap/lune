require "json"

module Lune
  module Runtime
    module Bindings
      class Screen
        include Lune::Installable

        def install(app : Lune::App)
          info(app)
        end

        private def info(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.screenInfo",
            args: [] of String,
            return_type: "String",
            async: false,
            runtime: true
          ) do |args|
            si = Lune::Native::Screen.info
            h = {
              "width"  => JSON::Any.new(si.width.to_i64),
              "height" => JSON::Any.new(si.height.to_i64),
              "scale"  => JSON::Any.new(si.scale),
            } of String => JSON::Any
            JSON::Any.new(h)
          end
        end
      end
    end
  end
end
