module Lune
  module Capabilities
    class Screen < Lune::Capability
      include Capability::BindPhase

      DESCRIPTOR = Descriptor.new(id: :screen, label: "Screen")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def install(ctx : BindCtx) : Nil
        ctx.define("info", return_type: "String", ts_return_type: "Promise<ScreenInfo>") do |_args|
          si = Lune::Native::Screen.info
          JSON::Any.new({
            "width"  => JSON::Any.new(si.width.to_i64),
            "height" => JSON::Any.new(si.height.to_i64),
            "scale"  => JSON::Any.new(si.scale),
          } of String => JSON::Any)
        end
      end
    end
  end
end
