module Lune
  abstract class Capability
    include Installable

    # Single source of truth for the internal bridge marker.
    # Interpolate everywhere instead of hardcoding the string literal.
    BRIDGE_MARKER = "__lune"
    SENTINEL_NS   = "capabilities.#{BRIDGE_MARKER}"

    # Unique camelCase name used in lune.yml capabilities include/exclude lists.
    abstract def name : String

    # true = infrastructure injected via wv.init; false = callable bridge binding.
    # Informational only — all capabilities participate equally in include/exclude.
    abstract def core? : Bool

    # PascalCase JS namespace for generated exports: System, Filesystem, DragOut, …
    # Uses Crystal's built-in .camelcase (lower: false = PascalCase by default).
    # Override in subclasses when a different public name is needed (e.g. "Events").
    def binding_namespace : String
      name.camelcase
    end

    # Namespaced JS key written as a sentinel when this capability is active.
    def sentinel_key : String
      "#{SENTINEL_NS}.#{name}"
    end

    # Returns true if the user has configured any options for this capability.
    # Used to warn in dev when a capability is inactive but its opts are set.
    def configured? : Bool
      false
    end

    # Register bindings on the app. Called in both build mode and runtime.
    def install(app : App) : Nil
    end

    # Inject JS or set up raw webview bindings. Called in runtime only (no webview in build mode).
    def init_webview(wv : Webview::Webview, handle : Pointer(Void), app : Lune::App) : Nil
    end

    # Method bodies for the generated `export const <Namespace> = { … }` object.
    # Return comma-separated object method definitions (PascalCase names, no `export` prefix).
    # Empty string means this capability contributes no JS helpers.
    def js_helpers : String
      ""
    end

    # Interface members for the generated `export interface <Namespace> { … }` block.
    # Return method signatures (no `export declare` prefix).
    # Empty string means this capability contributes no DTS helpers.
    def dts_helpers : String
      ""
    end
  end
end
