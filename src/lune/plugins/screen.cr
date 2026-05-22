module Lune
  module Plugins
    class Screen < Lune::Plugin
      include Lune::Bindable

      DESCRIPTOR = Descriptor.new(id: :screen, label: "Screen")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @[Lune::Bind]
      @[Lune::BindOverride(ts_return_type: "Promise<ScreenInfo>")]
      def info : NamedTuple(width: Int32, height: Int32, scale: Float64)
        Lune::Native::Screen.info
      end
    end
  end
end
