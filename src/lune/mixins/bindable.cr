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

  # Marks a Crystal struct / record / class as a TypeScript surface type. When
  # such a type appears as the return of a `@[Lune::Bind]` method, the macro
  # registers it via `Lune.register_ts_type` and the generator emits a named
  # `export interface <Name> { ... }` declaration in `runtime.d.ts`; the
  # binding's `ts_return_type` is set to `Promise<<Name>>` automatically.
  # Without this annotation, struct returns fall back to `Record<string, any>`
  # (or the author can inline the shape via `@[Lune::BindOverride(ts_return_type: ...)]`).
  annotation TsType; end

  # `include Lune::Bindable` turns a class into a bridge surface. The compiler
  # walks its methods, picks up every method tagged `@[Lune::Bind]`, and
  # generates an `install(app)` method that registers each as a `Lune::Binding`.
  #
  # The binding namespace is the Crystal class path verbatim — `@type.name`.
  # `Demo` stays `Demo`, `Lune::Plugins::Tray` becomes `Lune::Plugins::Tray`,
  # and `Binding#id` later splits `::` into `.` to produce the JS path
  # (`Demo.greet`, `Lune.Plugins.Tray.show`). User and plugin bindings go
  # through identical code; `internal:` only decides which JS file the binding
  # lands in (`app/App.js` vs `runtime/runtime.js`).
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
                # Auto-derive a TS string union from an enum return type unless
                # the author already set ts_return_type explicitly. Crystal's
                # default `Enum#to_json` lowercases + underscores the member
                # name, so the TS union must match (`Pending` → `"pending"`,
                # `TwoWords` → `"two_words"`).
                {% return_resolved = m.return_type.resolve? %}
                {% enum_return_union = (return_resolved && return_resolved.ancestors.includes?(Enum)) ? return_resolved.constants.map { |c| "\"" + c.stringify.underscore + "\"" }.join(" | ") : nil %}
                # TsType-annotated return: register the struct's fields so the
                # generator can emit `export interface <Name> { ... }`, and
                # wire `ts_return_type` to reference that name. Recognised by
                # `m.return_type.resolve.annotation(Lune::TsType)`.
                {% ts_type_ann = return_resolved && return_resolved.annotation(Lune::TsType) %}
                {% ts_type_name = ts_type_ann ? return_resolved.name.stringify.split("::").last : nil %}
                {% if ts_type_ann %}
                  Lune.register_ts_type(
                    {{ ts_type_name }},
                    [
                      {% for ivar in return_resolved.instance_vars %}
                        { {{ ivar.name.stringify }}, {{ ivar.type.stringify }} },
                      {% end %}
                    ] of Tuple(String, String)
                  )
                {% end %}
                app.register(Lune::Binding.new(
                  namespace: {{ @type.name.stringify }},
                  method: {{ m.name.stringify }},
                  args: {{ m.args.map(&.restriction.stringify) }} of String,
                  return_type: {{ m.return_type.stringify }},
                  internal: {{ is_plugin }},
                  async: {{ async }},
                  arg_names: {% if override_ann && override_ann[:arg_names] %}{{ override_ann[:arg_names] }}{% else %}{{ m.args.map(&.name.stringify) }} of String{% end %},
                  {% if override_ann && override_ann[:arg_transforms] %}arg_transforms: {{ override_ann[:arg_transforms] }},{% end %}
                  {% if override_ann && override_ann[:ts_args] %}ts_args: {{ override_ann[:ts_args] }},{% end %}
                  {% if override_ann && override_ann[:ts_return_type] %}
                    ts_return_type: {{ override_ann[:ts_return_type] }},
                  {% elsif ts_type_ann %}
                    ts_return_type: "Promise<{{ ts_type_name.id }}>",
                  {% elsif enum_return_union %}
                    ts_return_type: %(Promise<{{ enum_return_union.id }}>),
                  {% end %}
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
