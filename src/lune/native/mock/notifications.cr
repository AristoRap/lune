{% if flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      module NotificationsMock
        @@calls = [] of Symbol
        @@last_title : String? = nil
        @@last_body : String? = nil

        class_getter calls, last_title, last_body

        def self.reset
          @@calls.clear
          @@last_title = nil
          @@last_body = nil
        end

        def self.record_show(title : String, body : String)
          @@calls << :show
          @@last_title = title
          @@last_body = body
        end
      end

      module Notifications
        def self.show(title : String, body : String)
          NotificationsMock.record_show(title, body)
        end
      end
    end
  end
{% end %}
