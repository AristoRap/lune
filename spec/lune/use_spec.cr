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

# Two plugins whose `config` blocks both claim the same opts accessor.
# Used to verify that `Lune.use` rejects the second registration with a
# clear error instead of letting Crystal's silent method redefinition on
# `Lune::Options` decide which plugin wins.
private class AccessorClashA < Lune::Plugin
  DESCRIPTOR = Descriptor.new(id: :accessor_clash_a, label: "AccessorClashA")

  def descriptor : Descriptor
    DESCRIPTOR
  end

  config(:shared_accessor) do
    property foo : String = "a"
  end
end

private class AccessorClashB < Lune::Plugin
  DESCRIPTOR = Descriptor.new(id: :accessor_clash_b, label: "AccessorClashB")

  def descriptor : Descriptor
    DESCRIPTOR
  end

  config(:shared_accessor) do
    property foo : String = "b"
  end
end

private class CustomAccessorPlugin < Lune::Plugin
  DESCRIPTOR = Descriptor.new(id: :custom_accessor_plugin, label: "CustomAccessorPlugin")

  def descriptor : Descriptor
    DESCRIPTOR
  end

  config(:my_unique_accessor) do
    property foo : String = "x"
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

  it "raises on duplicate opts accessor name" do
    a = AccessorClashA.new
    b = AccessorClashB.new
    Lune.with_plugins(a) do
      expect_raises(ArgumentError, /accessor.*shared_accessor.*accessor_clash_a/) { Lune.use(b) }
    end
  end

  it "explicit accessor argument overrides the class-derived name" do
    plugin = CustomAccessorPlugin.new
    plugin.lune_options_accessor.should eq(:my_unique_accessor)
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
