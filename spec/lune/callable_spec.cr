require "../spec_helper"

private class GreetModule
  include Lune::Bindable

  @[Lune::Bind]
  def greet(msg : String) : String
    "Hello, #{msg}!"
  end
end

private struct AddArgs
  include JSON::Serializable
  getter a : Int32
  getter b : Int32
end

private class MathModule
  include Lune::Bindable

  @[Lune::Bind]
  def add(args : AddArgs) : Int32
    args.a + args.b
  end
end

describe "Lune::Bindable + App bindings" do
  it "registers bindings into App via install" do
    app = Lune::App.new

    app.install(GreetModule.new)

    app.bindings.size.should eq(1)
    app.bindings.first.name.should eq("greet")
    app.bindings.first.namespace.should eq("GreetModule")
  end

  it "supports multiple modules in one app" do
    app = Lune::App.new

    app.install(GreetModule.new)
    app.install(MathModule.new)

    names = app.bindings.map(&.name).sort
    namespaces = app.bindings.map(&.namespace).sort

    names.should eq(["add", "greet"])
    namespaces.should eq(["GreetModule", "MathModule"])
  end

  it "does not fail when installing modules" do
    app = Lune::App.new

    app.install(GreetModule.new)
    app.install(MathModule.new)

    app.bindings.empty?.should eq(false)
  end
end
