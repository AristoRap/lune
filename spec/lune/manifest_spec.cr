require "../spec_helper"

# Phase 1a parity harness: lune derives a `Vow::Manifest` from its existing
# `Lune::Binding` set. The manifest is the static contract later phases consume
# (interface emission, then dispatch on `Vow::Registry`), so these specs pin it
# to the *current* wire contract: one procedure per binding, named exactly by
# `Binding#id`, with matching arg names/types and return type — and it must
# round-trip through JSON so it can be snapshotted or served for introspection.

# A representative slice of the built-in surface: NamedTuple returns
# (System.environment, Sqlite.run), JSON::Any args (Sqlite.query/exec, Kv.set),
# multi-arg Int returns (Window), and plain Nil returns.
private def full_app : Lune::App
  app = Lune::App.new
  app.install(
    Lune::Plugins::System.new(on_quit: -> { }),
    Lune::Plugins::Window.new,
    Lune::Plugins::Sqlite.new,
    Lune::Plugins::Kv.new,
    Lune::Plugins::Filesystem.new,
    Lune::Plugins::Clipboard.new,
    Lune::Plugins::Dialogs.new,
  )
  app
end

describe "Lune manifest (vow contract)" do
  describe "Lune::Binding#to_vow_descriptor" do
    it "mirrors the binding's id, arg names/types, and return type" do
      b = Lune::Binding.new(
        namespace: "Lune::Plugins::Window",
        method: "set_size",
        args: ["Int32", "Int32"],
        return_type: "Nil",
        callback: ->(_a : Array(JSON::Any)) { JSON::Any.new(nil) },
        internal: true,
        async: false,
        arg_names: ["width", "height"],
      )

      d = b.to_vow_descriptor
      d.name.should eq("Lune.Plugins.Window.set_size")
      d.args.map(&.name).should eq(["width", "height"])
      d.args.map(&.type).should eq(["Int32", "Int32"])
      d.return_type.should eq("Nil")
      d.verb.should eq("post")
    end

    it "falls back to positional arg names when none are supplied" do
      b = Lune::Binding.new(
        namespace: "demo",
        method: "greet",
        args: ["String"],
        return_type: "String",
        callback: ->(_a : Array(JSON::Any)) { JSON::Any.new("hi") },
      )
      b.to_vow_descriptor.args.map(&.name).should eq(["arg0"])
    end

    it "produces a no-arg descriptor for a zero-arg binding" do
      b = Lune::Binding.new(
        namespace: "demo",
        method: "ping",
        args: [] of String,
        return_type: "Nil",
        callback: ->(_a : Array(JSON::Any)) { JSON::Any.new(nil) },
      )
      b.to_vow_descriptor.args.should be_empty
    end
  end

  describe "App#manifest" do
    it "emits exactly one procedure per binding" do
      app = full_app
      app.bindings.should_not be_empty
      app.manifest.procedures.size.should eq(app.bindings.size)
    end

    it "names every procedure by the binding's wire id" do
      app = full_app
      app.manifest.procedures.map(&.name).sort.should eq(app.bindings.map(&.id).sort)
    end

    it "captures a known plugin procedure faithfully" do
      app = Lune::App.new
      app.install(Lune::Plugins::Window.new)
      d = app.manifest.procedures.find { |p| p.name == "Lune.Plugins.Window.set_size" }.not_nil!
      d.args.map(&.type).should eq(["Int32", "Int32"])
      d.return_type.should eq("Nil")
    end

    it "round-trips through JSON" do
      app = full_app
      restored = Vow::Manifest.from_json(app.manifest.to_json)
      restored.procedures.map(&.name).sort.should eq(app.manifest.procedures.map(&.name).sort)
    end
  end
end
