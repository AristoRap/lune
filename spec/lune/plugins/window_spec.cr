require "../../spec_helper"

describe Lune::Plugins::Window do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Plugins::Window::DESCRIPTOR
      d.id.should eq(:window)
      d.label.should eq("Window")
    end

    it "is cross-platform" do
      Lune::Plugins::Window::DESCRIPTOR.platforms.should eq([:darwin, :linux, :win32])
    end

    it "is not core" do
      Lune::Plugins::Window::DESCRIPTOR.core.should be_false
    end
  end

  describe "phase membership" do
    it "includes Bindable (programmatic window controls)" do
      Lune::Plugins::Window.new.is_a?(Lune::Bindable).should be_true
    end

    it "includes WebviewInject (drag listener injection)" do
      Lune::Plugins::Window.new.is_a?(Lune::Plugin::WebviewInject).should be_true
    end
  end

  describe "drag_zone config" do
    it "defaults to an empty string" do
      Lune::Plugins::Window::Config.new.drag_zone.should be_empty
    end

    it "round-trips via opts.window assignment" do
      Lune.with_plugins(Lune::Plugins::Window.new) do
        opts = Lune::Options.new
        opts.window.drag_zone = "--lune-draggable"
        opts.window.drag_zone.should eq("--lune-draggable")
      end
    end

    it "round-trips via opts.window block" do
      Lune.with_plugins(Lune::Plugins::Window.new) do
        opts = Lune::Options.new
        opts.window do |w|
          w.drag_zone = "--lune-draggable"
        end
        opts.window.drag_zone.should eq("--lune-draggable")
      end
    end
  end

  describe "init_js" do
    it "returns nil when drag_zone is empty (no listener installed)" do
      Lune::Plugins::Window.new.init_js.should be_nil
    end

    {% if flag?(:darwin) || flag?(:win32) %}
      it "returns a listener script when drag_zone is set (darwin/win32)" do
        plugin = Lune::Plugins::Window.new
        plugin.config.drag_zone = "--lune-draggable"
        plugin.init_js.not_nil!.should contain("mousedown")
        plugin.init_js.not_nil!.should contain("--lune-draggable")
      end

      # The listener must invoke the binding by its actual dispatch id, which
      # camelCases the method leaf (`start_drag` → `startDrag`) — the same id the
      # bridge binds. A snake-case id here calls an undefined window fn (drag
      # silently dead).
      it "invokes the start_drag binding by its camelCased dispatch id" do
        plugin = Lune::Plugins::Window.new
        plugin.config.drag_zone = "--lune-draggable"
        js = plugin.init_js.not_nil!
        js.should contain(%(window["Lune.Plugins.Window.startDrag"]))
        js.should_not contain("start_drag")
      end
    {% else %}
      it "returns nil even when drag_zone is set on Linux" do
        plugin = Lune::Plugins::Window.new
        plugin.config.drag_zone = "--lune-draggable"
        plugin.init_js.should be_nil
      end
    {% end %}
  end
end
