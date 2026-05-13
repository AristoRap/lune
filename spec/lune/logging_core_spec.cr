require "../spec_helper"

private class CaptureBackend < Log::Backend
  getter entries = [] of Log::Entry

  def initialize
    super(:sync)
  end

  def write(entry : Log::Entry)
    @entries << entry
  end
end

private class LoggingFakeWebview
  include Lune::WebviewLike

  def initialize
    @bindings = {} of String => Proc(String, Array(JSON::Any), Nil)
  end

  def bind_deferred(name : String, &block : String, Array(JSON::Any) -> Nil)
    @bindings[name] = block
  end

  def invoke(name : String, seq : String, args : Array(JSON::Any))
    if handler = @bindings[name]?
      handler.call(seq, args)
    end
  end

  def dispatch(&block : ->)
    block.call
  end

  def resolve(seq : String, status : Int32, result : String)
  end

  def eval(js : String)
  end
end

describe "Lune core logging" do
  it "logs runtime JS writes" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.logging", backend, :debug)

    begin
      Lune.logger = logger

      with_tempdir do |tmpdir|
        Dir.cd(tmpdir) do
          Lune::Runtime.write_js([
            Lune::BindingDef.new(
              name: "ping",
              namespace: "test",
              args: [] of String,
              return_type: "void",
              callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(nil) },
              internal: false,
              async: false
            ),
          ])
        end
      end

      entry = backend.entries.find { |e| e.message.includes?("Lune JS written") }
      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Info)
    ensure
      Lune.logger = original
    end
  end

  it "logs bridge handler exceptions" do
    original = Lune.logger
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.logging", backend, :debug)

    begin
      Lune.logger = logger

      app = Lune::App.new

      app.bind(
        name: "boom",
        namespace: "test",
        args: [] of String,
        return_type: "void",
        async: false
      ) do |_args|
        raise "boom"
      end

      wv = LoggingFakeWebview.new
      bridge = Lune::Bridge.new(wv)

      bridge.register_bindings(app.bindings)
      app.bridge = bridge

      wv.invoke("test.boom", "seq-1", [] of JSON::Any)

      entry = backend.entries.find do |e|
        e.message.includes?("Binding execution failed")
      end

      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Error)
    ensure
      Lune.logger = original
    end
  end
end
