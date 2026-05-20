require "json"

module Lune
  module Capabilities
    class Kv < Lune::Capability
      include Capability::Bindable
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
        ctx.register(Definition.new(
          name: "#{name}.get",
          args: ["String"],
          return_type: "Any",
          arg_names: ["key"],
          ts_return_type: "Promise<unknown>",
          callback: ->(raw : Array(JSON::Any)) {
            key = raw[0].as_s
            @mu.synchronize { @store[key]? || JSON::Any.new(nil) }
          },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.set",
          args: ["String", "Any"],
          return_type: "Nil",
          arg_names: ["key", "value"],
          callback: ->(raw : Array(JSON::Any)) {
            key = raw[0].as_s
            @mu.synchronize { @store[key] = raw[1] }
            save_store
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.delete",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["key"],
          callback: ->(raw : Array(JSON::Any)) {
            key = raw[0].as_s
            @mu.synchronize { @store.delete(key) }
            save_store
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.has",
          args: ["String"],
          return_type: "Bool",
          arg_names: ["key"],
          ts_return_type: "Promise<boolean>",
          callback: ->(raw : Array(JSON::Any)) {
            key = raw[0].as_s
            JSON::Any.new(@mu.synchronize { @store.has_key?(key) })
          },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.keys",
          args: [] of String,
          return_type: "Array",
          ts_return_type: "Promise<string[]>",
          callback: ->(_raw : Array(JSON::Any)) {
            keys = @mu.synchronize { @store.keys.map { |k| JSON::Any.new(k) } }
            JSON::Any.new(keys)
          },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.clear",
          args: [] of String,
          return_type: "Nil",
          callback: ->(_raw : Array(JSON::Any)) {
            @mu.synchronize { @store.clear }
            save_store
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))
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
