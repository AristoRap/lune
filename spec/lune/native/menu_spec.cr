require "../../spec_helper"

describe Lune::Native::Menu do
  before_each { Lune::Native::MenuMock.reset }

  describe ".setup_default" do
    it "records a setup_default call" do
      Lune::Native::Menu.setup_default("My App")
      Lune::Native::MenuMock.calls.should contain(:setup_default)
    end

    it "records the app name" do
      Lune::Native::Menu.setup_default("My App")
      Lune::Native::MenuMock.last_app_name.should eq("My App")
    end

    it "accepts an empty app name" do
      Lune::Native::Menu.setup_default("")
      Lune::Native::MenuMock.calls.should contain(:setup_default)
      Lune::Native::MenuMock.last_app_name.should eq("")
    end

    it "records the most recent call when called multiple times" do
      Lune::Native::Menu.setup_default("First")
      Lune::Native::Menu.setup_default("Second")
      Lune::Native::MenuMock.last_app_name.should eq("Second")
      Lune::Native::MenuMock.calls.size.should eq(2)
    end
  end

  describe ".set_from_options" do
    it "records a set_menu call with the app name" do
      opts = Lune::Options::Menu.new
      opts.app_menu
      Lune::Native::Menu.set_from_options(opts, "Demo")
      Lune::Native::MenuMock.calls.should contain(:set_menu)
      Lune::Native::MenuMock.last_app_name.should eq("Demo")
    end

    it "produces valid JSON" do
      opts = Lune::Options::Menu.new
      opts.app_menu
      opts.submenu("File") do |f|
        f.item("New", shortcut: "cmd+n") { }
        f.separator
        f.item("Quit", shortcut: "cmd+q") { }
      end
      opts.edit_menu
      Lune::Native::Menu.set_from_options(opts, "Demo")
      json = Lune::Native::MenuMock.last_menu_json.not_nil!
      parsed = JSON.parse(json)
      parsed.as_a.size.should eq(3)
      parsed[0]["kind"].as_s.should eq("role_app")
      parsed[1]["kind"].as_s.should eq("submenu")
      parsed[1]["label"].as_s.should eq("File")
      parsed[1]["children"].as_a.size.should eq(3)
      parsed[2]["kind"].as_s.should eq("role_edit")
    end

    it "serializes text item fields" do
      opts = Lune::Options::Menu.new
      opts.submenu("File") { |f| f.item("New", shortcut: "cmd+n", enabled: true) { } }
      Lune::Native::Menu.set_from_options(opts, "App")
      json = Lune::Native::MenuMock.last_menu_json.not_nil!
      item = JSON.parse(json)[0]["children"][0]
      item["kind"].as_s.should eq("text")
      item["label"].as_s.should eq("New")
      item["key"].as_s.should eq("n")
      item["modifiers"].as_i64.should eq(Lune::Options::Menu::Shortcut::CMD.to_i64)
      item["enabled"].as_bool.should be_true
    end

    it "serializes checkbox item fields" do
      opts = Lune::Options::Menu.new
      opts.submenu("View") { |v| v.checkbox("Dark Mode", checked: true) { |_| } }
      Lune::Native::Menu.set_from_options(opts, "App")
      json = Lune::Native::MenuMock.last_menu_json.not_nil!
      item = JSON.parse(json)[0]["children"][0]
      item["kind"].as_s.should eq("checkbox")
      item["checked"].as_bool.should be_true
    end

    it "serializes radio item fields" do
      opts = Lune::Options::Menu.new
      opts.submenu("View") do |v|
        v.radio("Light", selected: true) { }
        v.radio("Dark") { }
      end
      Lune::Native::Menu.set_from_options(opts, "App")
      json = Lune::Native::MenuMock.last_menu_json.not_nil!
      children = JSON.parse(json)[0]["children"].as_a
      children[0]["kind"].as_s.should eq("radio")
      children[0]["checked"].as_bool.should be_true
      children[1]["checked"].as_bool.should be_false
    end

    it "serializes separator items" do
      opts = Lune::Options::Menu.new
      opts.submenu("File") { |f| f.separator }
      Lune::Native::Menu.set_from_options(opts, "App")
      json = Lune::Native::MenuMock.last_menu_json.not_nil!
      JSON.parse(json)[0]["children"][0]["kind"].as_s.should eq("separator")
    end

    it "serializes nested submenus" do
      opts = Lune::Options::Menu.new
      opts.submenu("File") do |f|
        f.submenu("Recent") do |r|
          r.item("doc.txt") { }
        end
      end
      Lune::Native::Menu.set_from_options(opts, "App")
      json = Lune::Native::MenuMock.last_menu_json.not_nil!
      inner = JSON.parse(json)[0]["children"][0]
      inner["kind"].as_s.should eq("submenu")
      inner["label"].as_s.should eq("Recent")
      inner["children"][0]["label"].as_s.should eq("doc.txt")
    end

    it "omits shortcut fields when shortcut is nil" do
      opts = Lune::Options::Menu.new
      opts.submenu("File") { |f| f.item("Open") { } }
      Lune::Native::Menu.set_from_options(opts, "App")
      json = Lune::Native::MenuMock.last_menu_json.not_nil!
      item = JSON.parse(json)[0]["children"][0]
      item["key"].as_s.should eq("")
      item["modifiers"].as_i.should eq(0)
    end
  end

  describe ".update" do
    it "re-applies the menu using the stored app name" do
      opts = Lune::Options::Menu.new
      opts.app_menu
      Lune::Native::Menu.set_from_options(opts, "MyApp")
      Lune::Native::MenuMock.reset
      Lune::Native::Menu.update(opts)
      Lune::Native::MenuMock.calls.should contain(:set_menu)
      Lune::Native::MenuMock.last_app_name.should eq("MyApp")
    end
  end

  describe ".show_context_menu" do
    it "records the call with coordinates and JSON" do
      Lune::Native::Menu.show_context_menu(Pointer(Void).null, 10.0_f32, 20.0_f32, "[{\"id\":\"cut\"}]") { }
      Lune::Native::MenuMock.calls.should contain(:show_context_menu)
      Lune::Native::MenuMock.last_context_json.should eq("[{\"id\":\"cut\"}]")
    end

    it "calls the block with the stubbed selection id" do
      Lune::Native::MenuMock.stub_context_selection("paste")
      selected = ""
      Lune::Native::Menu.show_context_menu(Pointer(Void).null, 0.0_f32, 0.0_f32, "[]") do |id|
        selected = id
      end
      selected.should eq("paste")
    end

    it "does not call the block when stub selection is empty (dismissed)" do
      called = false
      Lune::Native::Menu.show_context_menu(Pointer(Void).null, 0.0_f32, 0.0_f32, "[]") { called = true }
      called.should be_false
    end
  end
end
