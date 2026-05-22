{% if flag?(:linux) && !flag?(:lune_native_test_mock) %}
  require "base64"

  module Lune
    module Native
      # Linux has no native lib block — html/image paths shell out to xclip.
      module Clipboard
        def self.read : String
          raise NotImplementedError.new("Lune::Native::Clipboard.read — use the capability's DEFAULT_READ on non-Windows platforms")
        end

        def self.write(text : String) : Nil
          raise NotImplementedError.new("Lune::Native::Clipboard.write — use the capability's DEFAULT_WRITE on non-Windows platforms")
        end

        def self.read_html : String
          output = IO::Memory.new
          Process.run("xclip", ["-o", "-selection", "clipboard", "-t", "text/html"], output: output)
          output.to_s
        end

        def self.write_html(html : String) : Nil
          input = IO::Memory.new(html)
          Process.run("xclip", ["-i", "-selection", "clipboard", "-t", "text/html"], input: input)
        end

        def self.read_image : String
          output = IO::Memory.new
          status = Process.run("xclip", ["-o", "-selection", "clipboard", "-t", "image/png"], output: output)
          return "" unless status.success?
          raw = output.to_slice
          raw.empty? ? "" : "data:image/png;base64,#{Base64.strict_encode(raw)}"
        end

        def self.write_image(data_url : String) : Nil
          b64 = data_url.includes?(",") ? data_url.split(",", 2).last : data_url
          raw = Base64.decode(b64)
          input = IO::Memory.new(raw)
          Process.run("xclip", ["-i", "-selection", "clipboard", "-t", "image/png"], input: input)
        end
      end
    end
  end
{% end %}
