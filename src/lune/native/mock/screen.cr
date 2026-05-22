{% if flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      module ScreenMock
        @@calls = [] of Symbol
        @@stub_width = 1920
        @@stub_height = 1080
        @@stub_scale = 1.0

        class_getter calls

        def self.reset
          @@calls.clear
          @@stub_width = 1920
          @@stub_height = 1080
          @@stub_scale = 1.0
        end

        def self.stub_info(width : Int32, height : Int32, scale : Float64)
          @@stub_width = width
          @@stub_height = height
          @@stub_scale = scale
        end

        def self.record_info : ScreenInfo
          @@calls << :info
          ScreenInfo.new(@@stub_width, @@stub_height, @@stub_scale)
        end
      end

      module Screen
        def self.info : ScreenInfo
          ScreenMock.record_info
        end
      end
    end
  end
{% end %}
