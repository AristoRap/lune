module Lune
  module Capabilities
    class Filesystem < Lune::Capability
      include Lune::Bindable

      DESCRIPTOR = Descriptor.new(id: :filesystem, label: "Filesystem")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @[Lune::Bind]
      def home_dir : String
        Path.home.to_s
      end

      @[Lune::Bind]
      def temp_dir : String
        Dir.tempdir
      end

      @[Lune::Bind]
      def downloads_dir : String
        Path.home.join("Downloads").to_s
      end

      @[Lune::Bind]
      def app_data_dir : String
        {% if flag?(:darwin) %}
          Path.home.join("Library", "Application Support").to_s
        {% elsif flag?(:win32) %}
          ENV["APPDATA"]? || Path.home.to_s
        {% else %}
          ENV["XDG_DATA_HOME"]? || Path.home.join(".local", "share").to_s
        {% end %}
      end
    end
  end
end
