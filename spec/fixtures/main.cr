require "../../src/lune"

class GreetModule
  include Lune::Bindable

  @[Lune::Bind]
  def greet(msg : String = "stranger") : String
    "Hello, #{msg}!"
  end

  @[Lune::Bind(async: true)]
  def hello : String
    "Hello, world!"
  end
end

app = Lune::App.new
app.install(
  GreetModule.new
)
