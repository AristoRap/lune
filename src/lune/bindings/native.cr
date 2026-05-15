require "json"
require "../native/window"
require "../native/dialog"
require "../native/tray"
require "../native/notify"
require "../native/screen"

module Lune
  module Bindings
    module Native
      def self.build(window_handle : Void*, on_tray_click : (-> Nil)? = nil, on_menu_click : (String -> Nil)? = nil) : Array(Binding)
        handle = window_handle
        [
          # ── Window ───────────────────────────────────────────────────────────
          Binding.new(
            namespace: "runtime",
            method: "__lune.minimize",
            args: [] of String,
            return_type: "Nil",
            callback: ->(_args : Array(JSON::Any)) {
              Lune::Native::Window.minimize(handle)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          Binding.new(
            namespace: "runtime",
            method: "__lune.maximize",
            args: [] of String,
            return_type: "Nil",
            callback: ->(_args : Array(JSON::Any)) {
              Lune::Native::Window.maximize(handle)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          Binding.new(
            namespace: "runtime",
            method: "__lune.setTitle",
            args: ["String"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              Lune::Native::Window.set_title(handle, args[0].as_s)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          Binding.new(
            namespace: "runtime",
            method: "__lune.setSize",
            args: ["Int32", "Int32"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              Lune::Native::Window.set_size(handle, args[0].as_i, args[1].as_i)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          Binding.new(
            namespace: "runtime",
            method: "__lune.center",
            args: [] of String,
            return_type: "Nil",
            callback: ->(_args : Array(JSON::Any)) {
              Lune::Native::Window.center(handle)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),

          # ── Dialogs ──────────────────────────────────────────────────────────
          Binding.new(
            namespace: "runtime",
            method: "__lune.openFile",
            args: ["String"],
            return_type: "String",
            callback: ->(args : Array(JSON::Any)) {
              path = Lune::Native::Dialog.open_file(args[0].as_s)
              JSON::Any.new(path || "")
            },
            internal: true, async: false
          ),
          Binding.new(
            namespace: "runtime",
            method: "__lune.saveFile",
            args: ["String", "String"],
            return_type: "String",
            callback: ->(args : Array(JSON::Any)) {
              path = Lune::Native::Dialog.save_file(args[0].as_s, args[1].as_s)
              JSON::Any.new(path || "")
            },
            internal: true, async: false
          ),

          # ── System tray ──────────────────────────────────────────────────────
          Binding.new(
            namespace: "runtime",
            method: "__lune.trayShow",
            args: ["String"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              Lune::Native::Tray.show(args[0].as_s, on_tray_click)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          Binding.new(
            namespace: "runtime",
            method: "__lune.trayHide",
            args: [] of String,
            return_type: "Nil",
            callback: ->(_args : Array(JSON::Any)) {
              Lune::Native::Tray.hide
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          Binding.new(
            namespace: "runtime",
            method: "__lune.traySetIcon",
            args: ["String"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              Lune::Native::Tray.set_icon(args[0].as_s)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          Binding.new(
            namespace: "runtime",
            method: "__lune.traySetMenu",
            args: ["String"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              raw = Array(Hash(String, JSON::Any)).from_json(args[0].as_s)
              items = raw.map { |h| {id: h["id"].as_s, label: h["label"].as_s} }
              Lune::Native::Tray.set_menu(items, on_menu_click)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),

          # ── Notifications ────────────────────────────────────────────────────
          Binding.new(
            namespace: "runtime",
            method: "__lune.notify",
            args: ["String", "String"],
            return_type: "Nil",
            callback: ->(args : Array(JSON::Any)) {
              Lune::Native::Notify.show(args[0].as_s, args[1].as_s)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),

          # ── Screen ───────────────────────────────────────────────────────────
          Binding.new(
            namespace: "runtime",
            method: "__lune.screenInfo",
            args: [] of String,
            return_type: "String",
            callback: ->(_args : Array(JSON::Any)) {
              si = Lune::Native::Screen.info
              h = {
                "width"  => JSON::Any.new(si.width.to_i64),
                "height" => JSON::Any.new(si.height.to_i64),
                "scale"  => JSON::Any.new(si.scale),
              } of String => JSON::Any
              JSON::Any.new(h)
            },
            internal: true, async: false
          ),
        ]
      end
    end
  end
end
