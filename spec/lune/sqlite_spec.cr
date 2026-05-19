require "../spec_helper"

describe Lune::Capabilities::Sqlite do
  describe "descriptor" do
    it "has correct id and label" do
      d = Lune::Capabilities::Sqlite::DESCRIPTOR
      d.id.should eq(:sqlite)
      d.label.should eq("SQLite")
    end

    it "has no hard deps" do
      Lune::Capabilities::Sqlite::DESCRIPTOR.deps.should be_empty
    end

    it "is not core" do
      Lune::Capabilities::Sqlite::DESCRIPTOR.core.should be_false
    end
  end

  describe "name and namespace" do
    it "derives name from descriptor" do
      Lune::Capabilities::Sqlite.new.name.should eq("sqlite")
    end

    it "has Sqlite binding namespace" do
      Lune::Capabilities::Sqlite.new.binding_namespace.should eq("Sqlite")
    end
  end

  describe "phase membership" do
    it "includes Bindable" do
      Lune::Capabilities::Sqlite.new.is_a?(Lune::Capability::Bindable).should be_true
    end

    it "includes Lifecycle" do
      Lune::Capabilities::Sqlite.new.is_a?(Lune::Capability::Lifecycle).should be_true
    end

    it "does not include WebviewInject" do
      Lune::Capabilities::Sqlite.new.is_a?(Lune::Capability::WebviewInject).should be_false
    end
  end

  describe "install" do
    it "registers open, close, exec, and query bindings" do
      cap = Lune::Capabilities::Sqlite.new
      app = Lune::App.new
      app.install(cap)
      ids = app.bindings.map(&.id)
      ids.should contain("__lune.sqlite.open")
      ids.should contain("__lune.sqlite.close")
      ids.should contain("__lune.sqlite.exec")
      ids.should contain("__lune.sqlite.query")
    end

    it "open returns a 16-char hex db id for :memory:" do
      cap = Lune::Capabilities::Sqlite.new
      app = Lune::App.new
      app.install(cap)
      b = app.bindings.find { |b| b.id == "__lune.sqlite.open" }.not_nil!
      result = b.callback.call([JSON::Any.new(":memory:")])
      result.as_s.size.should eq(16)
    end

    it "close on a valid db_id returns nil" do
      cap = Lune::Capabilities::Sqlite.new
      app = Lune::App.new
      app.install(cap)
      open_b = app.bindings.find { |b| b.id == "__lune.sqlite.open" }.not_nil!
      close_b = app.bindings.find { |b| b.id == "__lune.sqlite.close" }.not_nil!
      id = open_b.callback.call([JSON::Any.new(":memory:")]).as_s
      result = close_b.callback.call([JSON::Any.new(id)])
      result.raw.should be_nil
    end

    it "close on unknown db_id is a no-op" do
      cap = Lune::Capabilities::Sqlite.new
      app = Lune::App.new
      app.install(cap)
      close_b = app.bindings.find { |b| b.id == "__lune.sqlite.close" }.not_nil!
      result = close_b.callback.call([JSON::Any.new("nonexistent")])
      result.raw.should be_nil
    end

    it "exec creates a table and returns changes=0, lastInsertId=0" do
      cap = Lune::Capabilities::Sqlite.new
      app = Lune::App.new
      app.install(cap)
      open_b = app.bindings.find { |b| b.id == "__lune.sqlite.open" }.not_nil!
      exec_b = app.bindings.find { |b| b.id == "__lune.sqlite.exec" }.not_nil!
      id = open_b.callback.call([JSON::Any.new(":memory:")]).as_s
      result = exec_b.callback.call([
        JSON::Any.new(id),
        JSON::Any.new("CREATE TABLE t (x INTEGER)"),
        JSON::Any.new([] of JSON::Any),
      ])
      result["changes"].as_i64.should eq(0)
      result["lastInsertId"].as_i64.should eq(0)
    end

    it "exec insert returns rows_affected and lastInsertId" do
      cap = Lune::Capabilities::Sqlite.new
      app = Lune::App.new
      app.install(cap)
      open_b = app.bindings.find { |b| b.id == "__lune.sqlite.open" }.not_nil!
      exec_b = app.bindings.find { |b| b.id == "__lune.sqlite.exec" }.not_nil!
      id = open_b.callback.call([JSON::Any.new(":memory:")]).as_s
      exec_b.callback.call([
        JSON::Any.new(id),
        JSON::Any.new("CREATE TABLE items (name TEXT, val INTEGER)"),
        JSON::Any.new([] of JSON::Any),
      ])
      result = exec_b.callback.call([
        JSON::Any.new(id),
        JSON::Any.new("INSERT INTO items VALUES (?, ?)"),
        JSON::Any.new([JSON::Any.new("hello"), JSON::Any.new(42_i64)]),
      ])
      result["changes"].as_i64.should eq(1)
      result["lastInsertId"].as_i64.should eq(1)
    end

    it "exec raises sqlite_not_open for unknown db_id" do
      cap = Lune::Capabilities::Sqlite.new
      app = Lune::App.new
      app.install(cap)
      exec_b = app.bindings.find { |b| b.id == "__lune.sqlite.exec" }.not_nil!
      expect_raises(Lune::Error, "No open database") do
        exec_b.callback.call([
          JSON::Any.new("bad"),
          JSON::Any.new("SELECT 1"),
          JSON::Any.new([] of JSON::Any),
        ])
      end
    end

    it "exec raises sqlite_error for bad SQL" do
      cap = Lune::Capabilities::Sqlite.new
      app = Lune::App.new
      app.install(cap)
      open_b = app.bindings.find { |b| b.id == "__lune.sqlite.open" }.not_nil!
      exec_b = app.bindings.find { |b| b.id == "__lune.sqlite.exec" }.not_nil!
      id = open_b.callback.call([JSON::Any.new(":memory:")]).as_s
      err = expect_raises(Lune::Error) do
        exec_b.callback.call([
          JSON::Any.new(id),
          JSON::Any.new("NOT VALID SQL !!!"),
          JSON::Any.new([] of JSON::Any),
        ])
      end
      err.code.should eq("sqlite_error")
    end

    it "query returns rows as array of hashes" do
      cap = Lune::Capabilities::Sqlite.new
      app = Lune::App.new
      app.install(cap)
      open_b = app.bindings.find { |b| b.id == "__lune.sqlite.open" }.not_nil!
      exec_b = app.bindings.find { |b| b.id == "__lune.sqlite.exec" }.not_nil!
      query_b = app.bindings.find { |b| b.id == "__lune.sqlite.query" }.not_nil!
      id = open_b.callback.call([JSON::Any.new(":memory:")]).as_s
      exec_b.callback.call([
        JSON::Any.new(id),
        JSON::Any.new("CREATE TABLE people (name TEXT, age INTEGER)"),
        JSON::Any.new([] of JSON::Any),
      ])
      exec_b.callback.call([
        JSON::Any.new(id),
        JSON::Any.new("INSERT INTO people VALUES ('Alice', 30)"),
        JSON::Any.new([] of JSON::Any),
      ])
      exec_b.callback.call([
        JSON::Any.new(id),
        JSON::Any.new("INSERT INTO people VALUES ('Bob', 25)"),
        JSON::Any.new([] of JSON::Any),
      ])
      rows = query_b.callback.call([
        JSON::Any.new(id),
        JSON::Any.new("SELECT * FROM people ORDER BY age"),
        JSON::Any.new([] of JSON::Any),
      ])
      arr = rows.as_a
      arr.size.should eq(2)
      arr[0]["name"].as_s.should eq("Bob")
      arr[0]["age"].as_i64.should eq(25)
      arr[1]["name"].as_s.should eq("Alice")
    end

    it "query with params uses ? placeholders" do
      cap = Lune::Capabilities::Sqlite.new
      app = Lune::App.new
      app.install(cap)
      open_b = app.bindings.find { |b| b.id == "__lune.sqlite.open" }.not_nil!
      exec_b = app.bindings.find { |b| b.id == "__lune.sqlite.exec" }.not_nil!
      query_b = app.bindings.find { |b| b.id == "__lune.sqlite.query" }.not_nil!
      id = open_b.callback.call([JSON::Any.new(":memory:")]).as_s
      exec_b.callback.call([
        JSON::Any.new(id),
        JSON::Any.new("CREATE TABLE nums (n INTEGER)"),
        JSON::Any.new([] of JSON::Any),
      ])
      exec_b.callback.call([
        JSON::Any.new(id),
        JSON::Any.new("INSERT INTO nums VALUES (1),(2),(3)"),
        JSON::Any.new([] of JSON::Any),
      ])
      rows = query_b.callback.call([
        JSON::Any.new(id),
        JSON::Any.new("SELECT n FROM nums WHERE n > ?"),
        JSON::Any.new([JSON::Any.new(1_i64)]),
      ])
      rows.as_a.size.should eq(2)
    end

    it "query returns empty array for no rows" do
      cap = Lune::Capabilities::Sqlite.new
      app = Lune::App.new
      app.install(cap)
      open_b = app.bindings.find { |b| b.id == "__lune.sqlite.open" }.not_nil!
      exec_b = app.bindings.find { |b| b.id == "__lune.sqlite.exec" }.not_nil!
      query_b = app.bindings.find { |b| b.id == "__lune.sqlite.query" }.not_nil!
      id = open_b.callback.call([JSON::Any.new(":memory:")]).as_s
      exec_b.callback.call([
        JSON::Any.new(id),
        JSON::Any.new("CREATE TABLE empty_t (x TEXT)"),
        JSON::Any.new([] of JSON::Any),
      ])
      rows = query_b.callback.call([
        JSON::Any.new(id),
        JSON::Any.new("SELECT * FROM empty_t"),
        JSON::Any.new([] of JSON::Any),
      ])
      rows.as_a.should be_empty
    end

    it "query raises sqlite_not_open for unknown db_id" do
      cap = Lune::Capabilities::Sqlite.new
      app = Lune::App.new
      app.install(cap)
      query_b = app.bindings.find { |b| b.id == "__lune.sqlite.query" }.not_nil!
      err = expect_raises(Lune::Error) do
        query_b.callback.call([
          JSON::Any.new("bad"),
          JSON::Any.new("SELECT 1"),
          JSON::Any.new([] of JSON::Any),
        ])
      end
      err.code.should eq("sqlite_not_open")
    end
  end

  describe "shutdown" do
    it "closes all open databases" do
      cap = Lune::Capabilities::Sqlite.new
      app = Lune::App.new
      app.install(cap)
      open_b = app.bindings.find { |b| b.id == "__lune.sqlite.open" }.not_nil!
      open_b.callback.call([JSON::Any.new(":memory:")])
      open_b.callback.call([JSON::Any.new(":memory:")])
      cap.shutdown
      # After shutdown, internal map is cleared — subsequent open works fine
      id = open_b.callback.call([JSON::Any.new(":memory:")]).as_s
      id.size.should eq(16)
    end
  end

  describe "registry integration" do
    it "is included in the default resolved set" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigCapabilities.new(only: nil, exclude: nil))
      resolved.capabilities.map(&.name).should contain("sqlite")
    end

    it "can be excluded" do
      r = Lune::Capabilities::Registry.new(Pointer(Void).null, Lune::Options.new, -> { })
      resolved = r.resolve(Lune::ConfigCapabilities.new(only: nil, exclude: ["sqlite"]))
      resolved.capabilities.map(&.name).should_not contain("sqlite")
    end
  end
end
