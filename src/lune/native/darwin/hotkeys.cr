{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  {% system("cd '#{__DIR__}/../../../../ext/native/darwin' && clang -c hotkeys.m -o hotkeys.o -fobjc-arc -Wno-deprecated-declarations 2>/dev/null") %}

  module Lune
    module Native
      @[Link(framework: "Carbon")]
      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../../ext/native/darwin/hotkeys.o")]
      lib LibNativeHotkeys
        fun lune_hotkeys_init(
          cb  : (LibC::Char*, Void*) ->,
          ctx : Void*
        ) : Void
        fun lune_hotkeys_register(accelerator : LibC::Char*) : LibC::Int
        fun lune_hotkeys_unregister(accelerator : LibC::Char*) : LibC::Int
        fun lune_hotkeys_unregister_all : Void
      end

      module Hotkeys
        @@box : Void*? = nil
        @@started : Bool = false

        def self.init(&handler : String -> Nil)
          cb = handler
          @@box = Box.box(cb)
          LibNativeHotkeys.lune_hotkeys_init(
            ->(key : LibC::Char*, ctx : Void*) {
              fn = Box(Proc(String, Nil)).unbox(ctx)
              fn.call(String.new(key))
            },
            @@box.not_nil!
          )
          @@started = true
        end

        def self.register(accelerator : String) : Bool
          return false unless @@started
          LibNativeHotkeys.lune_hotkeys_register(accelerator) != 0
        end

        def self.unregister(accelerator : String) : Bool
          return false unless @@started
          LibNativeHotkeys.lune_hotkeys_unregister(accelerator) != 0
        end

        def self.unregister_all : Nil
          LibNativeHotkeys.lune_hotkeys_unregister_all if @@started
          @@started = false
        end
      end
    end
  end
{% end %}
