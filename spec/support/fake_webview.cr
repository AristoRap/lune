class FakeWebview
  include Lune::WebviewLike

  getter eval_calls : Array(String)
  getter resolve_calls : Array(Tuple(String, Int32, String))

  def initialize
    @eval_calls = [] of String
    @resolve_calls = [] of Tuple(String, Int32, String)
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
    @resolve_calls << {seq, status, result}
  end

  def eval(js : String)
    @eval_calls << js
  end
end
