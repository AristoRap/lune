require "../spec_helper"

# A minimal plugin used to exercise the registration / lifecycle path without
# pulling in a built-in's native dependencies. Built-ins are registered at
# module load via `src/lune/plugins/builtins.cr`; the specs in here scope to a
# fresh registry via `Lune.with_plugins(...)` so they don't observe (or perturb)
# that global registration.
private class SpecPlugin < Lune::Plugin
  include Lune::Plugin::Lifecycle

  DESCRIPTOR = Descriptor.new(id: :spec_plugin, label: "SpecPlugin")

  def descriptor : Descriptor
    DESCRIPTOR
  end

  getter setup_calls = 0
  getter shutdown_calls = 0
  getter captured_on_quit : (-> Nil)? = nil

  def setup(ctx : SetupCtx) : Nil
    @setup_calls += 1
    @captured_on_quit = ctx.on_quit
  end

  def shutdown : Nil
    @shutdown_calls += 1
  end
end

describe "Lune.use" do
  it "registers a plugin so it appears in registered_plugins" do
    plugin = SpecPlugin.new
    Lune.with_plugins(plugin) do
      Lune.registered_plugins.should contain(plugin)
    end
  end

  it "raises on duplicate descriptor id" do
    a = SpecPlugin.new
    b = SpecPlugin.new
    Lune.with_plugins(a) do
      expect_raises(ArgumentError, /already registered/) { Lune.use(b) }
    end
  end

  it "with_plugins restores the previous registration set" do
    before_size = Lune.registered_plugins.size
    Lune.with_plugins(SpecPlugin.new) do
      Lune.registered_plugins.size.should eq(1)
    end
    Lune.registered_plugins.size.should eq(before_size)
  end

  it "Registry consumes the registered set" do
    plugin = SpecPlugin.new
    Lune.with_plugins(plugin) do
      registry = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new)
      registry.all.should contain(plugin)
    end
  end

  it "Registry forwards on_quit to setup via SetupCtx" do
    plugin = SpecPlugin.new
    quit_called = false
    on_quit = -> { quit_called = true; nil }

    Lune.with_plugins(plugin) do
      Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, on_quit: on_quit)
    end

    plugin.setup_calls.should eq(1)
    plugin.captured_on_quit.should_not be_nil
    plugin.captured_on_quit.not_nil!.call
    quit_called.should be_true
  end
end
