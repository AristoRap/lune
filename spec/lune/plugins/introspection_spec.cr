require "../../spec_helper"

# The Introspection plugin is an ordinary built-in, like Event and Stream: it
# exposes the app's live `Vow::Manifest` over a normal `@[Lune::Bind]` binding
# (so it rides the registry and the generated client like any other plugin
# method) and injects a `window.__lune.manifest` convenience wrapper over that
# binding. `lune.yml` decides whether the plugin is injected at all; the wrapper
# follows `opts.devtools` (read in `setup`), the same way FileDrop reads its
# config to decide what it emits.
private def setup_with_devtools(plugin : Lune::Plugins::Introspection, devtools : Bool) : Nil
  opts = Lune::Options.new
  opts.devtools = devtools
  plugin.setup(Lune::Plugin::SetupCtx.new(options: opts, handle: Pointer(Void).null))
end

describe Lune::Plugins::Introspection do
  it "registers a manifest binding under its plugin namespace" do
    app = Lune::App.new
    app.install(Lune::Plugins::Introspection.new, Lune::Plugins::Window.new)
    app.bindings.map(&.id).should contain("Lune.Plugins.Introspection.manifest")
  end

  describe "#manifest" do
    it "returns the app's live manifest, including its own procedure" do
      plugin = Lune::Plugins::Introspection.new
      app = Lune::App.new
      app.install(plugin, Lune::Plugins::Window.new)

      manifest = plugin.manifest
      names = manifest.procedures.map(&.name)
      names.should contain("Lune.Plugins.Window.setSize")
      names.should contain("Lune.Plugins.Introspection.manifest")
    end
  end

  describe "#init_js" do
    it "injects a window.__lune.manifest wrapper when devtools are on" do
      plugin = Lune::Plugins::Introspection.new
      setup_with_devtools(plugin, true)
      js = plugin.init_js
      js.should_not be_nil
      js.not_nil!.should contain("#{Lune::Plugin::BRIDGE_MARKER}.manifest")
      # Calls the binding by its flat dispatch-id key, as the bridge exposes it.
      js.not_nil!.should contain("Lune.Plugins.Introspection.manifest")
    end

    it "skips the wrapper when devtools are off" do
      plugin = Lune::Plugins::Introspection.new
      setup_with_devtools(plugin, false)
      plugin.init_js.should be_nil
    end
  end
end
