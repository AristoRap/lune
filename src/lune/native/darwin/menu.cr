{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/macos' && clang -c menu.m -o menu.o -fobjc-arc 2>/dev/null") %}

  module Lune
    module Native
      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/macos/menu.o")]
      lib LibNativeMenu
        fun setup_default_menu(app_name : LibC::Char*) : Void
        fun lune_set_menu(
          app_name : LibC::Char*,
          json     : LibC::Char*,
          cb       : (LibC::Char*, Void*) ->,
          ctx      : Void*
        ) : Void
        fun lune_show_context_menu(
          window : Void*,
          x      : LibC::Float,
          y      : LibC::Float,
          json   : LibC::Char*,
          cb     : (LibC::Char*, Void*) ->,
          ctx    : Void*
        ) : Void
      end

      module Menu
        @@box : Void*? = nil
        @@ctx_box : Void*? = nil

        def self.setup_default(app_name : String)
          LibNativeMenu.setup_default_menu(app_name)
        end

        def self.set_from_options(opts : Options::Menu, app_name : String)
          json = opts.to_json
          registry = collect_registry(opts.top_level)
          @@box = Box.box(registry)
          LibNativeMenu.lune_set_menu(
            app_name,
            json,
            ->(payload : LibC::Char*, ctx : Void*) {
              reg = Box(Hash(String, Options::Menu::Item)).unbox(ctx)
              dispatch(reg, String.new(payload))
            },
            @@box.not_nil!
          )
        end

        def self.show_context_menu(handle : Void*, x : Float32, y : Float32, items_json : String, &on_select : String -> Nil)
          cb = on_select
          box = Box.box(cb)
          @@ctx_box = box
          LibNativeMenu.lune_show_context_menu(
            handle, x, y, items_json,
            ->(payload : LibC::Char*, ctx : Void*) {
              fn = Box(Proc(String, Nil)).unbox(ctx)
              data = JSON.parse(String.new(payload))
              id = data["id"]?.try(&.as_s) || ""
              fn.call(id) unless id.empty?
            },
            box
          )
        end

        private def self.collect_registry(items : Array(Options::Menu::Item)) : Hash(String, Options::Menu::Item)
          hash = {} of String => Options::Menu::Item
          items.each { |item| collect_into(hash, item) }
          hash
        end

        private def self.collect_into(hash : Hash(String, Options::Menu::Item), item : Options::Menu::Item)
          case item.kind
          when Options::Menu::Item::Kind::Text, Options::Menu::Item::Kind::Checkbox, Options::Menu::Item::Kind::Radio
            hash[item.id] = item
          when Options::Menu::Item::Kind::Submenu
            item.children.each { |c| collect_into(hash, c) }
          end
        end

        private def self.dispatch(registry : Hash(String, Options::Menu::Item), payload : String)
          data = JSON.parse(payload)
          id = data["id"]?.try(&.as_s?) || return
          item = registry[id]? || return

          if item.kind.checkbox? || item.kind.radio?
            checked = data["checked"]?.try(&.as_bool?) || false
            item.checked = checked
            item.checked_callback.try(&.call(checked))
          else
            item.callback.try(&.call)
          end
        end
      end
    end
  end
{% end %}
