require "json"

module Lune
  module Capabilities
    class Kv < Lune::Capability
      include Capability::BindPhase
      include Capability::Lifecycle

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

      def install(ctx : BindCtx) : Nil
        ctx.define("get",
          args: ["String"],
          return_type: "Any",
          arg_names: ["key"],
          ts_return_type: "Promise<unknown>",
        ) do |raw|
          key = raw[0].as_s
          @mu.synchronize { @store[key]? || JSON::Any.new(nil) }
        end

        ctx.define("set",
          args: ["String", "Any"],
          arg_names: ["key", "value"],
        ) do |raw|
          key = raw[0].as_s
          @mu.synchronize { @store[key] = raw[1] }
          save_store
          JSON::Any.new(nil)
        end

        ctx.define("delete",
          args: ["String"],
          arg_names: ["key"],
        ) do |raw|
          key = raw[0].as_s
          @mu.synchronize { @store.delete(key) }
          save_store
          JSON::Any.new(nil)
        end

        ctx.define("has",
          args: ["String"],
          return_type: "Bool",
          arg_names: ["key"],
        ) do |raw|
          key = raw[0].as_s
          JSON::Any.new(@mu.synchronize { @store.has_key?(key) })
        end

        ctx.define("keys",
          return_type: "Array(String)",
        ) do |_raw|
          keys = @mu.synchronize { @store.keys.map { |k| JSON::Any.new(k) } }
          JSON::Any.new(keys)
        end

        ctx.define("clear") do |_raw|
          @mu.synchronize { @store.clear }
          save_store
          JSON::Any.new(nil)
        end
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
