require "../src/lune"

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

# runner = Lune::Runner.new(app) do |opts|
#   opts.width = 1400
#   opts.height = 800
# end

# runner.start

Lune.run(app) do |opts|
  opts.width = 1400
  opts.height = 800
end
