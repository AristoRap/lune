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
    end
  end
{% end %}
