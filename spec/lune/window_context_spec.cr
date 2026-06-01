require "../spec_helper"
require "../support/fake_webview"

# A user class with context-aware bindings: a leading `ctx : Lune::WindowContext`
# is injected by dispatch and never appears on the wire. `echo` proves the
# remaining args still decode after the injected context.
private class CtxModule
  include Lune::Bindable

  @[Lune::Bind]
  def whoami(ctx : Lune::WindowContext) : String
    ctx.seq
  end

  @[Lune::Bind]
  def echo(ctx : Lune::WindowContext, value : String) : String
    "#{ctx["seq"]}:#{value}"
  end
end

describe Lune::WindowContext do
  it "injects the context into a binding that declares a leading ctx param" do
    app = Lune::App.new
    app.install(CtxModule.new)
    ctx = Lune::WindowContext.new(seq: "seq-9", webview: FakeWebview.new)

    b = app.bindings.find { |x| x.id == "CtxModule.whoami" }.not_nil!
    JSON.parse(app.registry.dispatch(b.id, "{}", ctx)).as_s.should eq("seq-9")
  end

  it "decodes the remaining wire args after the injected ctx" do
    app = Lune::App.new
    app.install(CtxModule.new)
    ctx = Lune::WindowContext.new(seq: "seq-3", webview: FakeWebview.new)

    b = app.bindings.find { |x| x.id == "CtxModule.echo" }.not_nil!
    JSON.parse(app.registry.dispatch(b.id, %({"value": "hi"}), ctx)).as_s.should eq("seq-3:hi")
  end

  it "exposes seq through the generic Vow::Context accessor" do
    Lune::WindowContext.new(seq: "abc", webview: FakeWebview.new)["seq"].should eq("abc")
  end

  it "keeps the ctx param out of the wire args, manifest, and client signature" do
    app = Lune::App.new
    app.install(CtxModule.new)

    whoami = app.manifest.procedures.find { |p| p.name == "CtxModule.whoami" }.not_nil!
    whoami.args.should be_empty

    echo = app.manifest.procedures.find { |p| p.name == "CtxModule.echo" }.not_nil!
    echo.args.map(&.name).should eq(["value"])

    b = app.bindings.find { |x| x.id == "CtxModule.whoami" }.not_nil!
    b.to_dts_sig.should eq("  whoami(args?: {}): Promise<string>;")
  end
end
