require "../spec_helper"

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
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.logging", backend, :debug)

    with_logger(logger) do
      in_blank_project do
        Lune::Generator.write_js([
          Lune::Binding.new(
            namespace: "test",
            method: "ping",
            args: [] of String,
            return_type: "void",
            callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(nil) },
            internal: false,
            async: false
          ),
        ], "frontend/lunejs")
      end
    end

    entry = backend.entries.find { |e| e.message.includes?("Lune JS written") }
    entry.should_not be_nil
    entry.not_nil!.severity.should eq(Log::Severity::Info)
  end

  it "logs bridge handler exceptions" do
    backend = CaptureBackend.new
    logger = Log.new("lune.spec.logging", backend, :debug)

    with_logger(logger) do
      app = Lune::App.new

      app.bind(
        namespace: "test",
        method: "boom",
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
    end

    entry = backend.entries.find { |e| e.message.includes?("Binding execution failed") }
    entry.should_not be_nil
    entry.not_nil!.severity.should eq(Log::Severity::Error)
  end
end
