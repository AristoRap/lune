require "./spec_helper"

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
    @bindings[name].call(seq, args)
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
      Lune::Runtime.write_js(["ping"])

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
      wv = LoggingFakeWebview.new
      app = Lune::App.new(Lune::Bridge.new(wv))

      app.bind("boom") do |_args|
        raise "boom"
      end

      wv.invoke("boom", "seq-1", [] of JSON::Any)

      entry = backend.entries.find { |e| e.message.includes?("Binding execution failed") }
      entry.should_not be_nil
      entry.not_nil!.severity.should eq(Log::Severity::Error)
    ensure
      Lune.logger = original
    end
  end
end
