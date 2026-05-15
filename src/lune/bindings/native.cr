require "json"
require "../native/window"
require "../native/dialog"
require "../native/tray"
require "../native/notify"
require "../native/screen"

module Lune
  module Bindings
    module Native
      def self.build(window_handle : Void*, on_tray_click : (-> Nil)? = nil, on_menu_click : (String -> Nil)? = nil) : Array(BindingDef)
        handle = window_handle
        [
          # ── Window ───────────────────────────────────────────────────────────
          BindingDef.new(
            "__lune.minimize", "runtime", [] of String, "Nil",
            ->(_args : Array(JSON::Any)) {
              Lune::Native::Window.minimize(handle)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          BindingDef.new(
            "__lune.maximize", "runtime", [] of String, "Nil",
            ->(_args : Array(JSON::Any)) {
              Lune::Native::Window.maximize(handle)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          BindingDef.new(
            "__lune.setTitle", "runtime", ["String"], "Nil",
            ->(args : Array(JSON::Any)) {
              Lune::Native::Window.set_title(handle, args[0].as_s)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          BindingDef.new(
            "__lune.setSize", "runtime", ["Int32", "Int32"], "Nil",
            ->(args : Array(JSON::Any)) {
              Lune::Native::Window.set_size(handle, args[0].as_i, args[1].as_i)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          BindingDef.new(
            "__lune.center", "runtime", [] of String, "Nil",
            ->(_args : Array(JSON::Any)) {
              Lune::Native::Window.center(handle)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),

          # ── Dialogs ──────────────────────────────────────────────────────────
          BindingDef.new(
            "__lune.openFile", "runtime", ["String"], "String",
            ->(args : Array(JSON::Any)) {
              path = Lune::Native::Dialog.open_file(args[0].as_s)
              JSON::Any.new(path || "")
            },
            internal: true, async: false
          ),
          BindingDef.new(
            "__lune.saveFile", "runtime", ["String", "String"], "String",
            ->(args : Array(JSON::Any)) {
              path = Lune::Native::Dialog.save_file(args[0].as_s, args[1].as_s)
              JSON::Any.new(path || "")
            },
            internal: true, async: false
          ),

          # ── System tray ──────────────────────────────────────────────────────
          BindingDef.new(
            "__lune.trayShow", "runtime", ["String"], "Nil",
            ->(args : Array(JSON::Any)) {
              Lune::Native::Tray.show(args[0].as_s, on_tray_click)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          BindingDef.new(
            "__lune.trayHide", "runtime", [] of String, "Nil",
            ->(_args : Array(JSON::Any)) {
              Lune::Native::Tray.hide
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          BindingDef.new(
            "__lune.traySetIcon", "runtime", ["String"], "Nil",
            ->(args : Array(JSON::Any)) {
              Lune::Native::Tray.set_icon(args[0].as_s)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),
          BindingDef.new(
            "__lune.traySetMenu", "runtime", ["String"], "Nil",
            ->(args : Array(JSON::Any)) {
              raw = Array(Hash(String, JSON::Any)).from_json(args[0].as_s)
              items = raw.map { |h| {id: h["id"].as_s, label: h["label"].as_s} }
              Lune::Native::Tray.set_menu(items, on_menu_click)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),

          # ── Notifications ────────────────────────────────────────────────────
          BindingDef.new(
            "__lune.notify", "runtime", ["String", "String"], "Nil",
            ->(args : Array(JSON::Any)) {
              Lune::Native::Notify.show(args[0].as_s, args[1].as_s)
              JSON::Any.new(nil)
            },
            internal: true, async: false
          ),

          # ── Screen ───────────────────────────────────────────────────────────
          BindingDef.new(
            "__lune.screenInfo", "runtime", [] of String, "String",
            ->(_args : Array(JSON::Any)) {
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
