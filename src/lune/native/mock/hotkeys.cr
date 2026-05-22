{% if flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      module HotkeysMock
        @@registered = [] of String
        @@handler : (String -> Nil)? = nil

        def self.reset
          @@registered.clear
          @@handler = nil
        end

        def self.registered
          @@registered
        end

        def self.set_handler(cb : String -> Nil)
          @@handler = cb
        end

        def self.simulate(accelerator : String)
          @@handler.try(&.call(accelerator))
        end
      end

      module Hotkeys
        def self.init(&handler : String -> Nil)
          HotkeysMock.set_handler(handler)
        end

        def self.register(accelerator : String) : Bool
          HotkeysMock.registered << accelerator unless HotkeysMock.registered.includes?(accelerator)
          true
        end

        def self.unregister(accelerator : String) : Bool
          found = HotkeysMock.registered.includes?(accelerator)
          HotkeysMock.registered.delete(accelerator)
          found
        end

        def self.unregister_all : Nil
          HotkeysMock.registered.clear
        end
      end
    end
  end
{% end %}
