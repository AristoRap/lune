require "../spec_helper"

private class TestFileMenu < Lune::Options::Menu::Group
  def initialize
    super("File")
    item("New",  shortcut: "cmd+n") { }
    separator
    item("Quit", shortcut: "cmd+q") { }
  end
end

private class TestAppMenu < Lune::Options::Menu
  def initialize
    super()
    app_menu
    submenu(TestFileMenu.new)
  end
end

describe Lune::Options::Menu::Item do
  describe "defaults" do
    it "generates a unique id per instance" do
      a = Lune::Options::Menu::Item.new
      b = Lune::Options::Menu::Item.new
      a.id.should_not eq(b.id)
    end

    it "defaults to Text kind" do
      Lune::Options::Menu::Item.new.kind.should eq(Lune::Options::Menu::Item::Kind::Text)
    end

    it "defaults enabled to true" do
      Lune::Options::Menu::Item.new.enabled.should be_true
    end

    it "defaults checked to false" do
      Lune::Options::Menu::Item.new.checked.should be_false
    end

    it "defaults shortcut to nil" do
      Lune::Options::Menu::Item.new.shortcut.should be_nil
    end

    it "defaults children to empty" do
      Lune::Options::Menu::Item.new.children.should be_empty
    end

    it "defaults callback to nil" do
      Lune::Options::Menu::Item.new.callback.should be_nil
    end

    it "defaults checked_callback to nil" do
      Lune::Options::Menu::Item.new.checked_callback.should be_nil
    end
  end

  describe "mutable properties" do
    it "allows label mutation" do
      item = Lune::Options::Menu::Item.new(label: "Old")
      item.label = "New"
      item.label.should eq("New")
    end

    it "allows enabled mutation" do
      item = Lune::Options::Menu::Item.new
      item.enabled = false
      item.enabled.should be_false
    end

    it "allows checked mutation" do
      item = Lune::Options::Menu::Item.new(kind: Lune::Options::Menu::Item::Kind::Checkbox)
      item.checked = true
      item.checked.should be_true
    end
  end
end

describe Lune::Options::Menu::Group do
  describe "#item" do
    it "appends a Text item and returns it" do
      g = Lune::Options::Menu::Group.new("File")
      item = g.item("New") { }
      g.items.size.should eq(1)
      g.items.first.should be(item)
      item.kind.should eq(Lune::Options::Menu::Item::Kind::Text)
      item.label.should eq("New")
    end

    it "stores the click callback" do
      called = false
      g = Lune::Options::Menu::Group.new("File")
      item = g.item("New") { called = true }
      item.callback.not_nil!.call
      called.should be_true
    end

    it "sets shortcut" do
      g = Lune::Options::Menu::Group.new("File")
      item = g.item("New", shortcut: "cmd+n") { }
      item.shortcut.should eq("cmd+n")
    end

    it "respects enabled: false" do
      g = Lune::Options::Menu::Group.new("File")
      item = g.item("Grayed", enabled: false) { }
      item.enabled.should be_false
    end
  end

  describe "#separator" do
    it "appends a Separator item and returns it" do
      g = Lune::Options::Menu::Group.new("File")
      sep = g.separator
      g.items.size.should eq(1)
      sep.kind.should eq(Lune::Options::Menu::Item::Kind::Separator)
    end
  end

  describe "#checkbox" do
    it "appends a Checkbox item and returns it" do
      g = Lune::Options::Menu::Group.new("View")
      item = g.checkbox("Dark Mode") { |_| }
      item.kind.should eq(Lune::Options::Menu::Item::Kind::Checkbox)
      item.checked.should be_false
    end

    it "respects initial checked state" do
      g = Lune::Options::Menu::Group.new("View")
      item = g.checkbox("Sidebar", checked: true) { |_| }
      item.checked.should be_true
    end

    it "stores the checked callback" do
      received = false
      g = Lune::Options::Menu::Group.new("View")
      item = g.checkbox("Dark Mode") { |on| received = on }
      item.checked_callback.not_nil!.call(true)
      received.should be_true
    end
  end

  describe "#radio" do
    it "appends a Radio item and returns it" do
      g = Lune::Options::Menu::Group.new("View")
      item = g.radio("Light") { }
      item.kind.should eq(Lune::Options::Menu::Item::Kind::Radio)
    end

    it "respects selected: true" do
      g = Lune::Options::Menu::Group.new("View")
      item = g.radio("Dark", selected: true) { }
      item.checked.should be_true
    end

    it "stores the callback" do
      called = false
      g = Lune::Options::Menu::Group.new("View")
      item = g.radio("Light") { called = true }
      item.callback.not_nil!.call
      called.should be_true
    end
  end

  describe "#submenu" do
    it "appends a Submenu item with children" do
      g = Lune::Options::Menu::Group.new("File")
      sub = g.submenu("Recent") do |r|
        r.item("doc.txt") { }
        r.item("readme.md") { }
      end
      sub.kind.should eq(Lune::Options::Menu::Item::Kind::Submenu)
      sub.label.should eq("Recent")
      sub.children.size.should eq(2)
      g.items.first.should be(sub)
    end
  end

  it "accumulates items in order" do
    g = Lune::Options::Menu::Group.new("File")
    a = g.item("New") { }
    g.separator
    b = g.item("Open") { }
    g.items.map(&.object_id).should eq([a, g.items[1], b].map(&.object_id))
    g.items[1].kind.should eq(Lune::Options::Menu::Item::Kind::Separator)
  end
end

describe Lune::Options::Menu do
  describe "#app_menu" do
    it "appends a RoleApp item" do
      m = Lune::Options::Menu.new
      item = m.app_menu
      item.kind.should eq(Lune::Options::Menu::Item::Kind::RoleApp)
      m.top_level.first.should be(item)
    end
  end

  describe "#edit_menu" do
    it "appends a RoleEdit item" do
      m = Lune::Options::Menu.new
      item = m.edit_menu
      item.kind.should eq(Lune::Options::Menu::Item::Kind::RoleEdit)
      m.top_level.first.should be(item)
    end
  end

  describe "#submenu" do
    it "appends a Submenu item and yields a Group" do
      m = Lune::Options::Menu.new
      file_item = m.submenu("File") do |f|
        f.item("New") { }
        f.separator
        f.item("Quit") { }
      end
      file_item.kind.should eq(Lune::Options::Menu::Item::Kind::Submenu)
      file_item.label.should eq("File")
      file_item.children.size.should eq(3)
      m.top_level.size.should eq(1)
    end
  end

  describe "#any?" do
    it "returns false when empty" do
      Lune::Options::Menu.new.any?.should be_false
    end

    it "returns true after adding items" do
      m = Lune::Options::Menu.new
      m.app_menu
      m.any?.should be_true
    end
  end

  it "preserves top-level order" do
    m = Lune::Options::Menu.new
    app = m.app_menu
    file = m.submenu("File") { }
    edit = m.edit_menu
    m.top_level.map(&.object_id).should eq([app, file, edit].map(&.object_id))
  end
end

describe Lune::Options::Menu::Group do
  describe "subclass usage" do
    it "items built in initialize are available" do
      g = TestFileMenu.new
      g.items.size.should eq(3)
      g.items[0].label.should eq("New")
      g.items[1].kind.should eq(Lune::Options::Menu::Item::Kind::Separator)
      g.items[2].label.should eq("Quit")
    end

    it "submenu(group) overload uses group label and items" do
      parent = Lune::Options::Menu::Group.new("Top")
      child  = TestFileMenu.new
      sub    = parent.submenu(child)
      sub.kind.should eq(Lune::Options::Menu::Item::Kind::Submenu)
      sub.label.should eq("File")
      sub.children.size.should eq(3)
    end
  end
end

describe Lune::Options::Menu do
  describe "submenu(group) overload" do
    it "adds the group as a top-level submenu" do
      m = Lune::Options::Menu.new
      m.submenu(TestFileMenu.new)
      m.top_level.size.should eq(1)
      m.top_level[0].label.should eq("File")
      m.top_level[0].children.size.should eq(3)
    end
  end
end

describe Lune::Options do
  describe "#menu" do
    it "exposes a Menu instance" do
      Lune::Options.new.menu.should be_a(Lune::Options::Menu)
    end

    it "is empty by default" do
      Lune::Options.new.menu.any?.should be_false
    end

    it "mutations via block are retained" do
      opts = Lune::Options.new
      opts.menu do |m|
        m.app_menu
        m.submenu("File") do |f|
          f.item("Quit") { }
        end
        m.edit_menu
      end
      opts.menu.top_level.size.should eq(3)
      opts.menu.top_level[0].kind.should eq(Lune::Options::Menu::Item::Kind::RoleApp)
      opts.menu.top_level[1].kind.should eq(Lune::Options::Menu::Item::Kind::Submenu)
      opts.menu.top_level[2].kind.should eq(Lune::Options::Menu::Item::Kind::RoleEdit)
    end

    it "accepts a pre-built Menu instance" do
      m = TestAppMenu.new
      opts = Lune::Options.new
      opts.menu(m)
      opts.menu.should be(m)
      opts.menu.top_level.size.should eq(2)
    end
  end
end
