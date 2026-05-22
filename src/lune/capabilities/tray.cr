module Lune
  module Capabilities
    class Tray < Lune::Capability
      include Capability::BindPhase

      # Tray ships on all three platforms. Win32 implementation: show / hide /
      # clicks via Shell_NotifyIconW, menus via CreatePopupMenu + TrackPopupMenu,
      # icons via LoadImageW (.ico required — PNG falls back to IDI_APPLICATION
      # with a logger.warn). See website/capabilities/tray.md.
      DESCRIPTOR = Descriptor.new(id: :tray, label: "Tray", soft_deps: [:events], platforms: [:darwin, :linux, :win32])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def initialize(
        @event_name : String = "trayEvent",
        @on_tray_click : (-> Nil)? = nil,
        @on_right_click : (-> Nil)? = nil,
        @on_menu_click : (String -> Nil)? = nil,
      )
        @toggle_window_on = [] of Symbol
        @auto_show = false
        @handle = Pointer(Void).null
        @width = 0
        @height = 0
        @has_menu = false
      end

      def setup(ctx : SetupCtx) : Nil
        @event_name = ctx.options.tray.event
        @on_tray_click = ctx.options.tray.on_click
        @on_right_click = ctx.options.tray.on_right_click
        @on_menu_click = ctx.options.tray.on_menu_click
        @toggle_window_on = ctx.options.tray.toggle_window_on
        @auto_show = ctx.options.tray.auto_show
        @handle = ctx.handle
        @width = ctx.options.width
        @height = ctx.options.height
      end

      def configured? : Bool
        !@on_tray_click.nil? || !@on_menu_click.nil? || @event_name != "trayEvent"
      end

      # Resolve a click handler for one direction. Priority:
      #   1. user override → fires it (full takeover; no other behavior runs)
      #   2. else, toggle_window lambda (when click is listed in toggle_window_on)
      #   3. else, if a menu is set → pop it up
      #   4. else → emit `trayEvent` with the given payload
      def self.build_click_default(
        user_override : (-> Nil)?,
        events : Lune::Events,
        event_name : String,
        payload : String,
        toggle_window : (-> Nil)? = nil,
        has_menu : (-> Bool) = -> { false },
      ) : -> Nil
        return user_override.not_nil! if user_override
        toggle = toggle_window
        -> {
          if toggle
            toggle.call
          elsif has_menu.call
            Lune::Native::Tray.popup_menu
          else
            events.emit(event_name, payload)
          end
          nil
        }
      end

      # Builds the macOS "toggle window below tray icon" lambda used when a
      # click direction is listed in `toggle_window_on`. Returns nil if the
      # handle isn't set yet (capability not in a runtime).
      def self.build_window_toggle(handle : Pointer(Void), width : Int32, height : Int32) : (-> Nil)?
        return nil if handle.null?
        -> {
          {% if flag?(:darwin) %}
            if Lune::Native::Window.visible?(handle)
              Lune::Native::Window.hide(handle)
            else
              if rect = Lune::Native::Tray.button_screen_rect
                tray_x, tray_y, tray_w, _tray_h = rect
                x = tray_x + tray_w // 2 - width // 2
                y = tray_y - height
                Lune::Native::Window.set_frame(handle, x, y, width, height)
              end
              Lune::Native::Window.show(handle)
            end
          {% end %}
          nil
        }
      end

      private def window_toggle_for(direction : Symbol) : (-> Nil)?
        return nil unless @toggle_window_on.includes?(direction)
        Tray.build_window_toggle(@handle, @width, @height)
      end

      def install(ctx : BindCtx) : Nil
        event_name = @event_name
        has_menu_check = -> { @has_menu }
        on_tray_click = Tray.build_click_default(@on_tray_click, ctx.app.events, event_name, "left_click", window_toggle_for(:left_click), has_menu_check)
        on_right_click = Tray.build_click_default(@on_right_click, ctx.app.events, event_name, "right_click", window_toggle_for(:right_click), has_menu_check)

        ctx.define("show",
          args: ["String"],
          arg_names: ["iconPath"],
        ) do |args|
          Lune::Native::Tray.show(args[0].as_s, on_tray_click)
          Lune::Native::Tray.set_right_click_cb(on_right_click)
          JSON::Any.new(nil)
        end

        ctx.define("hide") do |_args|
          Lune::Native::Tray.hide
          JSON::Any.new(nil)
        end

        ctx.define("set_icon",
          args: ["String"],
          arg_names: ["path"],
        ) do |args|
          Lune::Native::Tray.set_icon(args[0].as_s)
          JSON::Any.new(nil)
        end

        ctx.define("popup_menu") do |_args|
          Lune::Native::Tray.popup_menu
          JSON::Any.new(nil)
        end

        on_menu_click = @on_menu_click || ->(id : String) { ctx.app.events.emit(event_name, id); nil }
        ctx.define("set_menu",
          args: ["String"],
          arg_names: ["items"],
          arg_transforms: ["JSON.stringify(items || [])"] of String?,
          ts_args: ["TrayMenuItem[]"] of String?,
        ) do |args|
          items = begin
            raw = Array(Hash(String, JSON::Any)).from_json(args[0].as_s)
            raw.compact_map do |h|
              id = h["id"]?.try(&.as_s?)
              label = h["label"]?.try(&.as_s?)
              next unless id && label
              {id: id, label: label}
            end
          rescue ex : JSON::ParseException
            Lune.logger.warn { "Tray.set_menu: invalid menu JSON — #{ex.message}" }
            [] of {id: String, label: String}
          end
          @has_menu = items.any?
          Lune::Native::Tray.set_menu(items, on_menu_click)
          JSON::Any.new(nil)
        end

        # Auto-show the tray icon at boot (driven by `opts.tray.auto_show`,
        # which `mac.menubar_mode` pre-fills). Wires the same click defaults
        # the JS-triggered `Tray.show` binding does, so behavior is consistent
        # whether the tray comes up at boot or on-demand.
        if @auto_show
          Lune::Native::Tray.show("", on_tray_click)
          Lune::Native::Tray.set_right_click_cb(on_right_click)
        end
      end

      def unavailable_js_stub(platform : Symbol) : String?
        ns = binding_namespace
        reject = ->(m : String) { %(return Promise.reject(new LuneError("UNAVAILABLE_ON_PLATFORM", "#{ns}.#{m} is not available on #{platform}"));) }
        <<-JS
        export const #{ns} = {
          show(iconPath) { #{reject.call("show")} },
          hide() { #{reject.call("hide")} },
          setIcon(path) { #{reject.call("setIcon")} },
          popupMenu() { #{reject.call("popupMenu")} },
          setMenu(items) { #{reject.call("setMenu")} },
        };
        JS
      end

      def unavailable_dts_stub : String?
        ns = binding_namespace
        <<-DTS
        export interface #{ns} {
          show(iconPath: string): Promise<void>;
          hide(): Promise<void>;
          setIcon(path: string): Promise<void>;
          popupMenu(): Promise<void>;
          setMenu(items: TrayMenuItem[]): Promise<void>;
        }
        DTS
      end
    end
  end
end
