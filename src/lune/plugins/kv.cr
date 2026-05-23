require "json"

module Lune
  module Plugins
    class Kv < Lune::Plugin
      include Lune::Bindable
      include Plugin::Lifecycle

      DESCRIPTOR = Descriptor.new(id: :kv, label: "Kv")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @store = {} of String => JSON::Any
      @mu = Mutex.new
      @path : String = ""

      def setup(ctx : SetupCtx) : Nil
        base = {% if flag?(:darwin) %}
          Path.home.join("Library", "Application Support").to_s
        {% elsif flag?(:win32) %}
          ENV["APPDATA"]? || Path.home.to_s
        {% else %}
          ENV["XDG_DATA_HOME"]? || Path.home.join(".local", "share").to_s
        {% end %}
        slug = ctx.options.title.downcase.gsub(/\s+/, "-").gsub(/[^a-z0-9\-]/, "")
        slug = "lune" if slug.empty?
        @path = File.join(base, slug, "kv.json")
        load_store
      end

      @[Lune::Bind]
      @[Lune::BindOverride(ts_return_type: "Promise<unknown>")]
      def get(key : String) : JSON::Any
        @mu.synchronize { @store[key]? || JSON::Any.new(nil) }
      end

      @[Lune::Bind]
      @[Lune::BindOverride(ts_args: [nil, "unknown"] of String?)]
      def set(key : String, value : JSON::Any) : Nil
        @mu.synchronize { @store[key] = value }
        save_store
      end

      @[Lune::Bind]
      def delete(key : String) : Nil
        @mu.synchronize { @store.delete(key) }
        save_store
      end

      @[Lune::Bind]
      def has(key : String) : Bool
        @mu.synchronize { @store.has_key?(key) }
      end

      @[Lune::Bind]
      def keys : Array(String)
        @mu.synchronize { @store.keys }
      end

      @[Lune::Bind]
      def clear : Nil
        @mu.synchronize { @store.clear }
        save_store
      end

      def shutdown : Nil
        save_store
      end

      private def load_store : Nil
        return unless File.exists?(@path)
        parsed = JSON.parse(File.read(@path))
        if hash = parsed.as_h?
          @mu.synchronize { @store = hash }
        end
      rescue
      end

      private def save_store : Nil
        return if @path.empty?
        Dir.mkdir_p(File.dirname(@path))
        File.write(@path, @mu.synchronize { @store }.to_json)
      rescue
      end
    end
  end
end
