module Lune
  module Capabilities
    class Filesystem < Lune::Capability
      include Capability::BindPhase

      DESCRIPTOR = Descriptor.new(id: :filesystem, label: "Filesystem")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      def install(ctx : BindCtx) : Nil
        ctx.define("home_dir", return_type: "String") do |_args|
          JSON::Any.new(Path.home.to_s)
        end

        ctx.define("temp_dir", return_type: "String") do |_args|
          JSON::Any.new(Dir.tempdir)
        end

        ctx.define("downloads_dir", return_type: "String") do |_args|
          JSON::Any.new(Path.home.join("Downloads").to_s)
        end

        ctx.define("app_data_dir", return_type: "String") do |_args|
          path =
            {% if flag?(:darwin) %}
              Path.home.join("Library", "Application Support").to_s
            {% elsif flag?(:win32) %}
              ENV["APPDATA"]? || Path.home.to_s
            {% else %}
              ENV["XDG_DATA_HOME"]? || Path.home.join(".local", "share").to_s
            {% end %}
          JSON::Any.new(path)
        end
      end
    end
  end
end
