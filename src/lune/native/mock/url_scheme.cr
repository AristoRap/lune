{% if flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      module UrlSchemeMock
        class_property registered = [] of {String, String, String}

        def self.reset
          @@registered.clear
        end
      end

      module UrlScheme
        def self.register(scheme : String, exe_path : String, display : String) : Bool
          UrlSchemeMock.registered << {scheme, exe_path, display}
          true
        end
      end
    end
  end
{% end %}
