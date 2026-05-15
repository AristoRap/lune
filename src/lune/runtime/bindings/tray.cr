require "json"

module Lune
  module Runtime
    module Bindings
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
          app.bind(
            namespace: "runtime",
            method: "__lune.trayShow",
            args: ["String"],
            return_type: "Nil",
            async: false,
            runtime: true
          ) do |args|
            Lune::Native::Tray.show(args[0].as_s, @on_tray_click)
            JSON::Any.new(nil)
          end
        end

        private def hide(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.trayHide",
            args: [] of String,
            return_type: "Nil",
            async: false,
            runtime: true
          ) do |_args|
            Lune::Native::Tray.hide
            JSON::Any.new(nil)
          end
        end

        private def set_icon(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.traySetIcon",
            args: ["String"],
            return_type: "Nil",
            async: false,
            runtime: true
          ) do |args|
            Lune::Native::Tray.set_icon(args[0].as_s)
            JSON::Any.new(nil)
          end
        end

        private def set_menu(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.traySetMenu",
            args: ["String"],
            return_type: "Nil",
            async: false,
            runtime: true
          ) do |args|
            raw = Array(Hash(String, JSON::Any)).from_json(args[0].as_s)
            items = raw.map { |h| {id: h["id"].as_s, label: h["label"].as_s} }
            Lune::Native::Tray.set_menu(items, @on_menu_click)
            JSON::Any.new(nil)
          end
        end
      end
    end
  end
end
