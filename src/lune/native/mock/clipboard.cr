{% if flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      module ClipboardMock
        @@text : String = ""
        @@html : String = ""
        @@image : String = ""

        class_getter text, html, image

        def self.reset
          @@text = ""
          @@html = ""
          @@image = ""
        end

        def self.stub_text(text : String)
          @@text = text
        end

        def self.stub_html(html : String)
          @@html = html
        end

        def self.stub_image(image : String)
          @@image = image
        end

        def self.record_read : String
          @@text
        end

        def self.record_write(text : String)
          @@text = text
        end

        def self.record_read_html : String
          @@html
        end

        def self.record_write_html(html : String)
          @@html = html
        end

        def self.record_read_image : String
          @@image
        end

        def self.record_write_image(data_url : String)
          @@image = data_url
        end
      end
    end
  end
{% end %}
