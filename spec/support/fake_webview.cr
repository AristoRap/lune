class FakeWebview
  include Lune::WebviewLike

  getter dispatch_count : Int32
  getter resolve_calls : Array(Tuple(String, Int32, String))

  def initialize
    @dispatch_count = 0
    @resolve_calls = [] of Tuple(String, Int32, String)
    @bindings = {} of String => Proc(String, Array(JSON::Any), Nil)
    @lock = Mutex.new
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
    @lock.synchronize { @dispatch_count += 1 }
    block.call
  end

  def resolve(seq : String, status : Int32, result : String)
    @lock.synchronize { @resolve_calls << {seq, status, result} }
  end

  def eval(js : String)
  end
end
