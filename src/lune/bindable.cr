require "json"

module Lune
  # Mixin that provides the full binding interface.
  #
  # Includers implement `bind` and `bind_async` concretely.
  # `bind_typed` is defined here once and delegates to `bind`.
  #
  # Multi-argument bindings use a single struct parameter:
  #
  #   struct AddArgs
  #     include JSON::Serializable
  #     getter a : Int32
  #     getter b : Int32
  #   end
  #
  #   app.bind_typed("add", AddArgs) { |args| args.a + args.b }
  #
  module Bindable
    abstract def bind(name : String, &block : Array(JSON::Any) -> JSON::Any)
    abstract def bind_async(name : String, &block : Array(JSON::Any) -> JSON::Any)

    def bind_typed(name : String, t : T.class, &block : T -> R) forall T, R
      bind(name) do |args|
        raise ArgumentError.new("Expected 1 argument, got #{args.size}") if args.size != 1

        a = Webview::TypedBinding.convert_from_json(args[0], t)
        Webview::TypedBinding.convert_to_json(block.call(a))
      end
    end
  end
end
