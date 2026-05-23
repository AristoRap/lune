require "../spec_helper"

# A plugin that declares its own config via the `config do` macro. The
# expectation is that the macro:
#   - generates a nested `Config` class with the declared properties
#   - exposes a `#config` getter on the plugin instance
#   - reopens `Lune::Options` with a typed accessor named after the simple
#     class name underscored (`Wrapped` → `opts.wrapped`)
private class Wrapped < Lune::Plugin
  DESCRIPTOR = Descriptor.new(id: :wrapped, label: "Wrapped")

  def descriptor : Descriptor
    DESCRIPTOR
  end

  config do
    property broker : String = "tcp://localhost:1883"
    property on_message : (String, String -> Nil)? = nil
  end
end

describe "Lune::Plugin.config" do
  it "defines a nested Config class with declared defaults" do
    cfg = Wrapped::Config.new
    cfg.broker.should eq("tcp://localhost:1883")
    cfg.on_message.should be_nil
  end

  it "exposes the plugin's config via #config" do
    plugin = Wrapped.new
    plugin.config.broker.should eq("tcp://localhost:1883")
  end

  it "Lune::Options gains a typed accessor that yields the config" do
    plugin = Wrapped.new
    Lune.with_plugins(plugin) do
      opts = Lune::Options.new
      opts.wrapped.broker.should eq("tcp://localhost:1883")
      opts.wrapped do |w|
        w.broker = "tcp://broker.example.com:1883"
      end
      opts.wrapped.broker.should eq("tcp://broker.example.com:1883")
    end
  end

  it "config mutations persist through the same plugin instance" do
    plugin = Wrapped.new
    Lune.with_plugins(plugin) do
      Lune::Options.new.wrapped.broker = "tcp://x:9999"
    end
    plugin.config.broker.should eq("tcp://x:9999")
  end

  it "raises a clear error when accessed before the plugin is registered" do
    Lune.with_plugins do
      expect_raises(Exception, /wrapped/) do
        Lune::Options.new.wrapped
      end
    end
  end
end
