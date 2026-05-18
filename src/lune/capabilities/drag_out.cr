module Lune
  module Capabilities
    class DragOut < Lune::Capability
      def initialize(@handle : Void*)
      end

      def name : String
        "drag_out"
      end


      def install(app : Lune::App)
        h = @handle
        app.register(Definition.new(
          name: "#{name}.start",
          args: ["String"],
          return_type: "Nil",
          callback: ->(args : Array(JSON::Any)) {
            Lune::Native::Window.start_drag_out(h, JSON.parse(args[0].as_s).as_a.map(&.as_s))
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))
      end

      # User-friendly wrapper: accepts a string[] and serialises to JSON for the bridge.
      # Shadows the raw bridge stub so the user always gets the array-accepting version.
      def js_helpers : String
        bridge_id = "#{BRIDGE_MARKER}.#{name}.start"
        <<-JS
          start(paths) { return __lune.call(#{bridge_id.inspect}, JSON.stringify(paths || [])); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          start(paths: string[]): Promise<void>;
        DTS
      end
    end
  end
end
