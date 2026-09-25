require "../spec_helper"

class Lune::Runner
  def setup_toolbar_options_for_spec(handle : Void*) : Nil
    setup_mac_window_options(handle)
  end
end

describe "macOS toolbar setup" do
  before_each { Lune::Native::WindowMock.reset }

  it "preserves existing window chrome by default" do
    runner = Lune::Runner.new(Lune::App.new) { |_| }
    runner.setup_toolbar_options_for_spec(Pointer(Void).null)
    Lune::Native::WindowMock.calls.should_not contain(:set_toolbar_style)
  end

  it "forwards every explicit style, including Automatic" do
    Lune::Options::Mac::ToolbarStyle.each do |style|
      runner = Lune::Runner.new(Lune::App.new) do |opts|
        opts.mac.toolbar_style = style
      end
      runner.setup_toolbar_options_for_spec(Pointer(Void).null)
      Lune::Native::WindowMock.last_toolbar_style.should eq(style.value)
    end
  end

  it "applies title and traffic-light visibility after attaching the toolbar" do
    runner = Lune::Runner.new(Lune::App.new) do |opts|
      opts.mac do |mac|
        mac.toolbar_style = Lune::Options::Mac::ToolbarStyle::UnifiedCompact
        mac.full_size_content = true
        mac.hide_title = true
        mac.hide_traffic_lights = true
      end
    end
    runner.setup_toolbar_options_for_spec(Pointer(Void).null)
    Lune::Native::WindowMock.calls.should eq([
      :set_titlebar_transparent, :set_toolbar_style, :hide_title, :hide_traffic_lights,
    ])
  end
end
