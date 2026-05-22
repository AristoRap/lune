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

        def self.record_info : NamedTuple(width: Int32, height: Int32, scale: Float64)
          @@calls << :info
          {width: @@stub_width, height: @@stub_height, scale: @@stub_scale}
        end
      end

      module Screen
        def self.info : NamedTuple(width: Int32, height: Int32, scale: Float64)
          ScreenMock.record_info
        end
      end
    end
  end
{% end %}
