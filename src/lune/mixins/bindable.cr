require "json"

module Lune
  # Marks a method as exposed across the bridge. The macro that picks this up
  # is provided by `Lune::Bindable`. On its own this annotation does nothing.
  annotation Bind; end

  # Optional companion to `@[Bind]`. Supplies fields the macro can't infer from
  # the Crystal method signature: `arg_names` (JS-side parameter names — useful
  # when the Crystal arg name doesn't camelCase to the desired JS name),
  # `arg_transforms` (JS-side wrapper expressions, e.g. `JSON.stringify(items)`),
  # `ts_args` (TS-side argument types), `ts_return_type` (TS-side full return
  # type bypassing the default `Promise<T>` auto-wrap).
  annotation BindOverride; end

  # `include Lune::Bindable` turns a class into a bridge surface. The compiler
  # walks its methods, picks up every method tagged `@[Lune::Bind]`, and generates
  # an `install(app)` method that registers each as a `Lune::Binding`.
  #
  # User and plugin bindings share the same bridge-ID shape (`<Namespace>.<method>`).
  # `internal:` only decides which JS file the binding lands in:
  #
  #   - User class (plain Bindable): namespace = class name, internal: false.
  #     Binding lands in `app.js` as `api.<Class>.method`.
  #
  #   - Plugin subclass: namespace = `binding_namespace`, internal: true.
  #     Binding lands in `runtime.js` (and the per-plugin file under `plugins/`)
  #     under the plugin's namespace. Extra fields (TS types, JS arg transforms)
  #     come from `@[BindOverride]` on the same method.
  module Bindable
    include Installable
    getter app : Lune::App = Lune::App.new

    macro included
      def install(app : Lune::App) : Nil
        {% verbatim do %}
          {% begin %}
            @app = app
            {% is_plugin = @type.ancestors.includes?(Lune::Plugin) %}
            {% for m in @type.methods %}
              {% if bind_ann = m.annotation(Lune::Bind) %}
                {% override_ann = m.annotation(Lune::BindOverride) %}
                {% async = bind_ann[:async] && bind_ann[:async].id == "true" ? true : false %}
                app.register(Lune::Binding.new(
                  namespace: {% if is_plugin %}binding_namespace{% else %}{{ @type.name.stringify }}{% end %},
                  method: {{ m.name.stringify }},
                  args: {{ m.args.map(&.restriction.stringify) }} of String,
                  return_type: {{ m.return_type.stringify }},
                  internal: {{ is_plugin }},
                  async: {{ async }},
                  arg_names: {% if override_ann && override_ann[:arg_names] %}{{ override_ann[:arg_names] }}{% else %}{{ m.args.map(&.name.stringify) }} of String{% end %},
                  {% if override_ann && override_ann[:arg_transforms] %}arg_transforms: {{ override_ann[:arg_transforms] }},{% end %}
                  {% if override_ann && override_ann[:ts_args] %}ts_args: {{ override_ann[:ts_args] }},{% end %}
                  {% if override_ann && override_ann[:ts_return_type] %}ts_return_type: {{ override_ann[:ts_return_type] }},{% end %}
                  callback: ->(__args : Array(JSON::Any)) : JSON::Any {
                    raise ArgumentError.new("expected {{ m.args.size }} arg(s), got #{__args.size}") unless __args.size == {{ m.args.size }}
                    {% for arg, i in m.args %}
                      __arg{{ i }} = {{ arg.restriction }}.from_json(__args[{{ i }}].to_json)
                    {% end %}
                    result = {{ m.name.id }}({% for arg, i in m.args %}{% if i > 0 %}, {% end %}__arg{{ i }}{% end %})
                    JSON.parse(result.to_json)
                  }
                ))
              {% end %}
            {% end %}
          {% end %}
        {% end %}
      end
    end
  end
end
