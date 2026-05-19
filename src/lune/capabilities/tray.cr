module Lune
  module Capabilities
    class Tray < Lune::Capability
      include Capability::Bindable

      DESCRIPTOR = Descriptor.new(id: :tray, label: "Tray", soft_deps: [:event_bus])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def initialize(
        @event_name : String = "trayEvent",
        @on_tray_click : (-> Nil)? = nil,
        @on_menu_click : (String -> Nil)? = nil,
      )
      end

      def setup(ctx : SetupCtx) : Nil
        @event_name = ctx.options.tray.event
        @on_tray_click = ctx.options.tray.on_click
        @on_menu_click = ctx.options.tray.on_menu_click
      end

      def configured? : Bool
        !@on_tray_click.nil? || !@on_menu_click.nil? || @event_name != "trayEvent"
      end

      def js_helpers : String
        bridge_id = "#{BRIDGE_MARKER}.#{name}.set_menu"
        <<-JS
          setMenu(items) { return __lune.call(#{bridge_id.inspect}, JSON.stringify(items || [])); },
        JS
      end

      def dts_helpers : String
        <<-DTS
          setMenu(items: TrayMenuItem[]): Promise<void>;
        DTS
      end


      def install(ctx : BindCtx) : Nil
        event_name = @event_name
        on_tray_click = @on_tray_click || -> { ctx.app.emit(event_name, "click"); nil }
        ctx.register(Definition.new(
          name: "#{name}.show",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["iconPath"],
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Tray.show(args[0].as_s, on_tray_click); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.hide",
          args: [] of String,
          return_type: "Nil",
          callback: ->(_args : Array(JSON::Any)) { Lune::Native::Tray.hide; JSON::Any.new(nil) },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.set_icon",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["path"],
          callback: ->(args : Array(JSON::Any)) { Lune::Native::Tray.set_icon(args[0].as_s); JSON::Any.new(nil) },
        ).binding(binding_namespace))

        on_menu_click = @on_menu_click || ->(id : String) { ctx.app.emit(event_name, id); nil }
        ctx.register(Definition.new(
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
