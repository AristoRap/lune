require "json"

module Lune
  module Runtime
    module Bindings
      private class TraySetMenuBinding < Lune::RuntimeBinding
        def to_js_stub : String
          "export function traySetMenu(items) { return __lune.call(#{id.inspect}, JSON.stringify(items)); }"
        end

        def to_dts_sig : String
          "export declare function traySetMenu(items: { id: string; label: string }[]): Promise<void>;"
        end
      end

      class Tray
        include Lune::Installable

        def initialize(@on_tray_click : (-> Nil)? = nil, @on_menu_click : (String -> Nil)? = nil)
        end

        def install(app : Lune::App)
          show(app)
          hide(app)
          set_icon(app)
          set_menu(app)
        end

        private def show(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.trayShow",
            args: ["String"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              Lune::Native::Tray.show(args[0].as_s, @on_tray_click)
              JSON::Any.new(nil)
            },
            arg_names: ["iconPath"],
          ))
        end

        private def hide(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.trayHide",
            args: [] of String,
            return_type: "Nil",
            callback: ->(_args : Array(JSON::Any)) {
              Lune::Native::Tray.hide
              JSON::Any.new(nil)
            },
          ))
        end

        private def set_icon(app : Lune::App)
          app.register(Lune::RuntimeBinding.new(
            namespace: "runtime",
            method: "__lune.traySetIcon",
            args: ["String"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              Lune::Native::Tray.set_icon(args[0].as_s)
              JSON::Any.new(nil)
            },
            arg_names: ["path"],
          ))
        end

        private def set_menu(app : Lune::App)
          app.register(TraySetMenuBinding.new(
            namespace: "runtime",
            method: "__lune.traySetMenu",
            args: ["String"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              raw = Array(Hash(String, JSON::Any)).from_json(args[0].as_s)
              items = raw.map { |h| {id: h["id"].as_s, label: h["label"].as_s} }
              Lune::Native::Tray.set_menu(items, @on_menu_click)
              JSON::Any.new(nil)
            },
          ))
        end
      end
    end
  end
end
