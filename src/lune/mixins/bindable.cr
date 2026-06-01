require "json"
require "vow/codegen/collect"
require "vow/exportable"

module Lune
  # Marks a method as exposed across the bridge. `Lune::Bindable` picks it up and
  # hands it to vow's `vow_register_marked` for dispatch generation; on its own
  # the annotation does nothing. `@[Lune::Bind(async: true)]` schedules the call
  # on lune's async pool (async is a lune-side concern vow never learns).
  annotation Bind; end

  # Optional companion to `@[Bind]`. Supplies TS-side detail the generator can't
  # infer from the Crystal signature: `ts_args` (per-arg TS types) and
  # `ts_return_type` (full return type, bypassing the default `Promise<T>` wrap).
  # Wire arg keys come from the Crystal parameter names (camelCased) — rename the
  # parameter if you want a different key.
  annotation BindOverride; end

  # `include Lune::Bindable` turns a class into a bridge surface. It mixes in
  # vow's `Vow::Exportable::Marked` and generates an `install(app)` that:
  #   * drives `vow_register_marked(app.registry, Lune::Bind)` — vow registers
  #     every `@[Lune::Bind]` method with its own decode → invoke → JSON-encode
  #     dispatch callback (the same code behind `@[Vow::Export]`), so lune no
  #     longer maintains a parallel copy; and
  #   * registers a `Lune::Binding` per method carrying the metadata lune's
  #     framework owns and vow doesn't — async scheduling, plugin/user `.d.ts`
  #     routing (`internal:`), and TS overrides — plus captures the surface types.
  #
  # The binding namespace is the Crystal class path verbatim (`@type.name`);
  # `Binding#id` splits `::`→`.` and camelCases the method leaf, matching the
  # `proc_name` vow registers, so the Bridge binds and dispatches the same id.
  module Bindable
    include Installable
    getter app : Lune::App = Lune::App.new

    macro included
      include ::Vow::Exportable::Marked

      def install(app : Lune::App) : Nil
        @app = app
        {% verbatim do %}
          {% begin %}
            # Dispatch: vow generates and registers the callback for every
            # `@[Lune::Bind]` method (decode named args → invoke → JSON-encode).
            # Driven by lune's own annotation via vow's generic marker seam.
            vow_register_marked(app.registry, Lune::Bind)

            {% is_plugin = @type.ancestors.includes?(Lune::Plugin) %}
            # Surface types reachable from the bound signatures, captured
            # transitively by vow and registered so the generator can emit a
            # named `interface` per `JSON::Serializable` struct (no annotation).
            __vow_types = [] of ::Vow::TypeDescriptor
            {% for m in @type.methods %}
              {% if bind_ann = m.annotation(Lune::Bind) %}
                {% override_ann = m.annotation(Lune::BindOverride) %}
                {% async = bind_ann[:async] && bind_ann[:async].id == "true" ? true : false %}
                # A leading parameter typed `Vow::Context` (or a subclass, e.g.
                # `Lune::WindowContext`) is injected by the bridge at dispatch
                # (vow's `vow_register_marked` does the injection) — so it must
                # be kept out of the wire args, the manifest, the captured types,
                # and the generated client signature. `payload` is the args that
                # actually cross the boundary.
                {% ctx_arg = false %}
                {% if m.args.size > 0 && (r0 = m.args[0].restriction).is_a?(Path) %}
                  {% rr0 = r0.resolve %}
                  {% ctx_arg = rr0 == ::Vow::Context || rr0.ancestors.includes?(::Vow::Context) %}
                {% end %}
                {% payload = ctx_arg ? m.args[1..-1] : m.args %}
                # The return type is supplied explicitly — not mapped from the
                # Crystal type, and not captured — only when an author set
                # `ts_return_type`. Enums need no special case here: vow captures
                # them as string-literal unions wherever they appear (top-level
                # or nested in a NamedTuple/struct), the same path as any surface
                # type.
                {% has_explicit_return = override_ann && override_ann[:ts_return_type] %}
                # Metadata for the generator (and the manifest/parity contract).
                # No callback: dispatch lives solely in the Vow::Registry above.
                # `arg_names` are the Crystal parameter names — camelCased into
                # wire keys by `Binding#arg_keys`, matching vow's keys exactly.
                app.register(Lune::Binding.new(
                  namespace: {{ @type.name.stringify }},
                  method: {{ m.name.stringify }},
                  # Resolved (not raw) arg-type strings: expanding aliases turns
                  # `Array(FileFilter)` into its `NamedTuple(...)` form so the
                  # generator inlines it instead of choking on the bare alias.
                  # Struct args stay matchable — `known` is keyed by resolved
                  # crystal_name as well as basename.
                  args: {{ payload.map(&.restriction.resolve.stringify) }} of String,
                  return_type: {{ m.return_type.stringify }},
                  internal: {{ is_plugin }},
                  async: {{ async }},
                  arg_names: {{ payload.map(&.name.stringify) }} of String,
                  {% if override_ann && override_ann[:ts_args] %}ts_args: {{ override_ann[:ts_args] }},{% end %}
                  {% if override_ann && override_ann[:ts_return_type] %}
                    ts_return_type: {{ override_ann[:ts_return_type] }},
                  {% end %}
                ))
                # Capture the surface types this signature references. Unions are
                # unwrapped at the call site (a union node can't survive a
                # macro-call argument). The return leg is skipped when an explicit
                # TS type already stands in for it. Pass the *resolved* node so it
                # resolves regardless of where the generated `install` lands.
                {% unless has_explicit_return %}
                  {% rr = m.return_type.resolve %}
                  {% if rr.union? %}
                    {% for u in rr.union_types %}::Vow::Codegen.collect(__vow_types, {{ u }}, ""){% end %}
                  {% else %}
                    ::Vow::Codegen.collect(__vow_types, {{ rr }}, "")
                  {% end %}
                {% end %}
                {% for arg in payload %}
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
