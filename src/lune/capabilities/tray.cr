module Lune
  module Capabilities
    class Tray < Lune::Capability
      def initialize(@on_tray_click : (-> Nil)? = nil, @on_menu_click : (String -> Nil)? = nil)
      end

      def name : String
        "tray"
      end

      def core? : Bool
        false
      end

      def configured? : Bool
        !@on_tray_click.nil? || !@on_menu_click.nil?
      end

      def js_helpers : String
        bridge_id = "#{BRIDGE_MARKER}.#{name}.set_menu"
        <<-JS
          SetMenu(items) { return __lune.call(#{bridge_id.inspect}, JSON.stringify(items || [])); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          SetMenu(items: TrayMenuItem[]): Promise<void>;
        DTS
      end

      def install(app : Lune::App)
        on_tray_click = @on_tray_click
        app.register(Definition.new(
          name: "#{name}.show",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["iconPath"],
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Tray.show(args[0].as_s, on_tray_click); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        app.register(Definition.new(
          name: "#{name}.hide",
          args: [] of String,
          return_type: "Nil",
          callback: ->(_args : Array(JSON::Any)) { Lune::Native::Tray.hide; JSON::Any.new(nil) },
        ).binding(binding_namespace))

        app.register(Definition.new(
          name: "#{name}.set_icon",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["path"],
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Tray.set_icon(args[0].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        on_menu_click = @on_menu_click
        app.register(Definition.new(
          name: "#{name}.set_menu",
          args: ["String"],
          return_type: "Nil",
          callback: ->(args : Array(JSON::Any)) {
            raw = Array(Hash(String, JSON::Any)).from_json(args[0].as_s)
            items = raw.map { |h| {id: h["id"].as_s, label: h["label"].as_s} }
            Lune::Native::Tray.set_menu(items, on_menu_click)
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))
      end
    end
  end
end
