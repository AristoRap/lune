module Lune
  module Plugins
    class Tray < Lune::Plugin
      include Lune::Bindable

      # Tray ships on all three platforms. Win32 implementation: show / hide /
      # clicks via Shell_NotifyIconW, menus via CreatePopupMenu + TrackPopupMenu,
      # icons via LoadImageW (.ico required — PNG falls back to IDI_APPLICATION
      # with a logger.warn). See website/plugins/tray.md.
      DESCRIPTOR = Descriptor.new(id: :tray, label: "Tray", soft_deps: [:event], platforms: [:darwin, :linux, :win32])

      def descriptor : Descriptor
        DESCRIPTOR
      end

      config do
        # Event name emitted via the event bus on tray icon click and menu item
        # selection. Defaults to `"trayEvent"`. Ignored when `on_click` /
        # `on_menu_click` are set explicitly.
        property event : String = "trayEvent"

        # Optional override: called on left-click of the tray icon. When set,
        # takes precedence over every default behavior (toggle, menu, emit).
        property on_click : (-> Nil)? = nil

        # Optional override: called on right-click (or Ctrl-click) of the tray
        # icon. When set, takes precedence over every default behavior.
        property on_right_click : (-> Nil)? = nil

        # Optional override: called when a tray context menu item is selected.
        # Receives the item id. When set, takes precedence over the default
        # event emission.
        property on_menu_click : (String -> Nil)? = nil

        # Click directions that toggle the app window (positioned below the
        # tray icon on macOS). Listed clicks override the menu/emit default;
        # user `on_click` / `on_right_click` overrides still win.
        # Valid values: `:left_click`, `:right_click`.
        property toggle_window_on : Array(Symbol) = [] of Symbol

        # When true, the tray icon is shown automatically at app start without
        # requiring a JS `lune.Tray.show("")` call. Auto-enabled by
        # `opts.menubar_mode`.
        property auto_show : Bool = false
      end

      def initialize
        @handle = Pointer(Void).null
        @width = 0
        @height = 0
        @has_menu = false
      end

      def setup(ctx : SetupCtx) : Nil
        @handle = ctx.handle
        @width = ctx.options.width
        @height = ctx.options.height
      end

      def configured? : Bool
        !@config.on_click.nil? || !@config.on_menu_click.nil? || @config.event != "trayEvent"
      end

      # Resolve a click handler for one direction. Priority:
      #   1. user override → fires it (full takeover; no other behavior runs)
      #   2. else, toggle_window lambda (when click is listed in toggle_window_on)
      #   3. else, if a menu is set → pop it up
      #   4. else → emit `trayEvent` with the given payload
      def self.build_click_default(
        user_override : (-> Nil)?,
        event_bus : Lune::Event,
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
            event_bus.emit(event_name, payload)
          end
          nil
        }
      end

      # Builds the "toggle window relative to tray icon" lambda used when a
      # click direction is listed in `toggle_window_on`. Returns nil if the
      # handle isn't set yet (plugin not in a runtime). macOS positions the
      # window below the menu-bar icon; Windows positions it above the
      # taskbar icon — same math (`y = tray_y - height`) works for both
      # because the OS coordinate origin and tray location flip together.
      def self.build_window_toggle(handle : Pointer(Void), width : Int32, height : Int32) : (-> Nil)?
        return nil if handle.null?
        -> {
          {% if flag?(:darwin) || flag?(:win32) %}
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
        return nil unless @config.toggle_window_on.includes?(direction)
        Tray.build_window_toggle(@handle, @width, @height)
      end

      # Build click handlers lazily so they capture the now-attached @app.
      # Memoized so multiple show / set_menu calls share the same closures.
      private def on_tray_click_handler : -> Nil
        @on_tray_click_handler ||= Tray.build_click_default(
          @config.on_click, @app.event, @config.event, "left_click",
          window_toggle_for(:left_click), -> { @has_menu })
      end

      private def on_right_click_handler : -> Nil
        @on_right_click_handler ||= Tray.build_click_default(
          @config.on_right_click, @app.event, @config.event, "right_click",
          window_toggle_for(:right_click), -> { @has_menu })
      end

      private def on_menu_click_handler : String -> Nil
        @on_menu_click_handler ||= @config.on_menu_click || ->(id : String) { @app.event.emit(@config.event, id); nil }
      end

      # Hook the macro-generated install: run the binding registration, then
      # auto-show the tray icon at boot when `opts.tray.auto_show` is set
      # (driven by `opts.menubar_mode`). Same click defaults the JS-triggered
      # `Tray.show` binding uses, so behavior is consistent boot vs on-demand.
      def install(app : Lune::App) : Nil
        previous_def
        if @config.auto_show
          Lune::Native::Tray.show("", on_tray_click_handler)
          Lune::Native::Tray.set_right_click_cb(on_right_click_handler)
        end
      end

      @[Lune::Bind]
      @[Lune::BindOverride(arg_names: ["iconPath"])]
      def show(icon_path : String) : Nil
        Lune::Native::Tray.show(icon_path, on_tray_click_handler)
        Lune::Native::Tray.set_right_click_cb(on_right_click_handler)
      end

      @[Lune::Bind]
      def hide : Nil
        Lune::Native::Tray.hide
      end

      @[Lune::Bind]
      def set_icon(path : String) : Nil
        Lune::Native::Tray.set_icon(path)
      end

      @[Lune::Bind]
      def popup_menu : Nil
        Lune::Native::Tray.popup_menu
      end

      @[Lune::Bind]
      @[Lune::BindOverride(arg_names: ["items"], arg_transforms: ["JSON.stringify(items || [])"] of String?, ts_args: ["{ id: string; label: string }[]"] of String?)]
      def set_menu(items_json : String) : Nil
        items = begin
          raw = Array(Hash(String, JSON::Any)).from_json(items_json)
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
        Lune::Native::Tray.set_menu(items, on_menu_click_handler)
      end

      def unavailable_js_stub(platform : Symbol) : String?
        ns = binding_namespace.gsub("::", ".")
        reject = ->(m : String) { %(return Promise.reject(new LuneError("UNAVAILABLE_ON_PLATFORM", "#{ns}.#{m} is not available on #{platform}"));) }
        <<-JS
          show(iconPath) { #{reject.call("show")} },
          hide() { #{reject.call("hide")} },
          setIcon(path) { #{reject.call("setIcon")} },
          popupMenu() { #{reject.call("popupMenu")} },
          setMenu(items) { #{reject.call("setMenu")} },
        JS
      end

      def unavailable_dts_stub : String?
        <<-DTS
          show(iconPath: string): Promise<void>;
          hide(): Promise<void>;
          setIcon(path: string): Promise<void>;
          popupMenu(): Promise<void>;
          setMenu(items: { id: string; label: string }[]): Promise<void>;
        DTS
      end
    end
  end
end
