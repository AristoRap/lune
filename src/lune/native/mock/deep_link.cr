{% if flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      module DeepLinkMock
        @@handler : (String -> Nil)? = nil

        def self.reset
          @@handler = nil
        end

        def self.set_handler(handler : String -> Nil)
          @@handler = handler
        end

        def self.simulate(url : String)
          @@handler.try(&.call(url))
        end
      end
    end
  end
{% end %}
