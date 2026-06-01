require "json"
require "vow/codegen/collect"
require "vow/registry"
require "vow/context"

module Lune
  # Marks a method as exposed across the bridge. The macro that picks this up
  # is provided by `Lune::Bindable`. On its own this annotation does nothing.
  annotation Bind; end

  # Optional companion to `@[Bind]`. Supplies fields the macro can't infer from
  # the Crystal method signature: `arg_names` (the named-object wire keys — useful
  # when the Crystal arg name doesn't camelCase to the desired key), `ts_args`
  # (TS-side argument types), `ts_return_type` (TS-side full return type bypassing
  # the default `Promise<T>` auto-wrap).
  annotation BindOverride; end

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
            # Surface types reachable from this class's bound signatures, captured
            # transitively by vow and registered alongside the bindings so the
            # generator can emit a named `interface` per `JSON::Serializable`
            # struct (no annotation needed).
            __vow_types = [] of ::Vow::TypeDescriptor
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
                # The return type is supplied explicitly (so it isn't mapped from
                # the Crystal type, and must not be captured) when an author set
                # `ts_return_type` or when it's an enum union. Skipping capture
                # here also keeps `collect` off enums, which it can't represent.
                {% has_explicit_return = (override_ann && override_ann[:ts_return_type]) || enum_return_union %}
                # The dispatch id (Crystal class path with `::`→`.`, raw method
                # leaf) — must equal `Lune::Binding#id` so the registry resolves
                # the same name the Bridge binds.
                {% ns = @type.name.stringify.split("::").join(".") %}
                {% proc_id = ns.empty? ? m.name.stringify : ns + "." + m.name.stringify %}
                # The named-object callback: decode each arg from the JSON object
                # by its camelCased wire key (the @[Lune::BindOverride(arg_names:)]
                # override, else the Crystal param name), via vow's typed decoder
                # (a bad/missing arg becomes a `Vow::Error.bad_input`), then call
                # by Crystal param name. Registered into the app's Vow::Registry
                # and also held on the Binding for direct/test invocation.
                %cb = ->(__args : Hash(String, JSON::Any), __ctx : ::Vow::Context?) : JSON::Any {
                  {% for arg, i in m.args %}
                    {% arg_name = (override_ann && override_ann[:arg_names]) ? override_ann[:arg_names][i] : arg.name.stringify %}
                    {% key = arg_name.camelcase(lower: true) %}
                    {% if arg.default_value.is_a?(Nop) %}
                      raise ::Vow::Error.bad_input("#{{{ proc_id }}} is missing required argument {{ key.id }}") unless __args.has_key?({{ key }})
                      __arg{{ i }} = ::Vow::Registry.decode({{ arg.restriction }}, __args[{{ key }}])
                    {% else %}
                      __arg{{ i }} =
                        if __args.has_key?({{ key }})
                          ::Vow::Registry.decode({{ arg.restriction }}, __args[{{ key }}])
                        else
                          {{ arg.default_value }}
                        end
                    {% end %}
                  {% end %}
                  __result = {{ m.name.id }}({% for arg, i in m.args %}{% if i > 0 %}, {% end %}{{ arg.name.id }}: __arg{{ i }}{% end %})
                  JSON.parse(__result.to_json)
                }
                app.register(Lune::Binding.new(
                  namespace: {{ @type.name.stringify }},
                  method: {{ m.name.stringify }},
                  args: {{ m.args.map(&.restriction.stringify) }} of String,
                  return_type: {{ m.return_type.stringify }},
                  internal: {{ is_plugin }},
                  async: {{ async }},
                  arg_names: {% if override_ann && override_ann[:arg_names] %}{{ override_ann[:arg_names] }}{% else %}{{ m.args.map(&.name.stringify) }} of String{% end %},
                  {% if override_ann && override_ann[:ts_args] %}ts_args: {{ override_ann[:ts_args] }},{% end %}
                  {% if override_ann && override_ann[:ts_return_type] %}
                    ts_return_type: {{ override_ann[:ts_return_type] }},
                  {% elsif enum_return_union %}
                    ts_return_type: %(Promise<{{ enum_return_union.id }}>),
                  {% end %}
                  callback: %cb,
                ))
                app.registry.register({{ proc_id }}, &%cb)
                # Capture the surface types this signature references. Unions are
                # unwrapped at the call site (a union node can't survive a
                # macro-call argument). The return leg is skipped when an explicit
                # TS type already stands in for it.
                # Pass the *resolved* (fully-qualified) type node so it resolves
                # regardless of where the generated `install` lands — an
                # unqualified name (`CounterState`) written inside a module
                # wouldn't resolve from here.
                {% unless has_explicit_return %}
                  {% rr = m.return_type.resolve %}
                  {% if rr.union? %}
                    {% for u in rr.union_types %}::Vow::Codegen.collect(__vow_types, {{ u }}, ""){% end %}
                  {% else %}
                    ::Vow::Codegen.collect(__vow_types, {{ rr }}, "")
                  {% end %}
                {% end %}
                {% for arg in m.args %}
                  {% ar = arg.restriction.resolve %}
                  {% if ar.union? %}
                    {% for u in ar.union_types %}::Vow::Codegen.collect(__vow_types, {{ u }}, ""){% end %}
                  {% else %}
                    ::Vow::Codegen.collect(__vow_types, {{ ar }}, "")
                  {% end %}
                {% end %}
              {% end %}
            {% end %}
            app.register_types(__vow_types, {{ is_plugin }})
          {% end %}
        {% end %}
      end
    end
  end
end
