require "../../spec_helper"

private def nav_with_callback : Lune::Plugins::Navigation
  cap = Lune::Plugins::Navigation.new
  opts = Lune::Options.new.tap { |o| o.on_navigate = ->(_u : String) {} }
  cap.setup(Lune::Plugin::SetupCtx.new(opts, Pointer(Void).null))
  cap
end

describe Lune::Plugins::Navigation do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Plugins::Navigation::DESCRIPTOR
      d.id.should eq(:navigation)
      d.label.should eq("Navigation")
    end

    it "has no hard deps" do
      Lune::Plugins::Navigation::DESCRIPTOR.deps.should be_empty
    end

    it "is not core" do
      Lune::Plugins::Navigation::DESCRIPTOR.core.should be_false
    end

    it "runs on every platform" do
      Lune::Plugins::Navigation::DESCRIPTOR.platforms.should eq([:darwin, :linux, :win32])
    end
  end

  describe "phase membership" do
    it "includes Bindable (changed callback is a @[Bind] method)" do
      Lune::Plugins::Navigation.new.is_a?(Lune::Bindable).should be_true
    end

    it "does not include WebviewInject (no longer hand-binds via wv.bind)" do
      Lune::Plugins::Navigation.new.is_a?(Lune::Plugin::WebviewInject).should be_false
    end
  end

  describe "registry integration" do
    it "is included in the default resolved set" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigPlugins.new(enabled: nil, disabled: nil))
      resolved.plugins.map(&.name).should contain("navigation")
    end

    it "can be excluded via config" do
      r = Lune::Plugins::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigPlugins.new(enabled: nil, disabled: ["navigation"]))
      resolved.plugins.map(&.name).should_not contain("navigation")
    end
  end

  describe "#init_js" do
    it "returns nil when no on_navigate is configured" do
      Lune::Plugins::Navigation.new.init_js.should be_nil
    end

    it "listens for popstate" do
      nav_with_callback.init_js.not_nil!.should contain("'popstate'")
    end

    it "listens for hashchange" do
      nav_with_callback.init_js.not_nil!.should contain("'hashchange'")
    end

    it "patches history.pushState so SPA routers fire on_navigate" do
      nav_with_callback.init_js.not_nil!.should contain("history.pushState = ")
    end

    it "patches history.replaceState so SPA routers fire on_navigate" do
      nav_with_callback.init_js.not_nil!.should contain("history.replaceState = ")
    end

    it "calls back through the Navigation.changed binding" do
      nav_with_callback.init_js.not_nil!.should contain("\"Navigation.changed\"")
    end

    it "dedupes back-to-back fires for the same URL (vue-router hash mode triggers both pushState and hashchange per click)" do
      js = nav_with_callback.init_js.not_nil!
      js.should contain("_last")
      js.should match(/===?\s*_last|_last\s*===?/)
    end
  end
end
