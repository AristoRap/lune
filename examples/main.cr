require "lune"

class GreetModule
  include Lune::Installable

  def install(app : Lune::App)
    app.bind_typed("greet", String) do |msg|
      "Hello, #{msg}!"
    end
  end
end

Lune.run(
  title: "myApp",
  assets: "frontend/dist",
  width: 1200,
  height: 800,
  debug: true
) do |app|
  app.install(GreetModule.new)

  app.namespace("counter") do |counter|
    counter.bind_typed("inc", Int32) { |n| n + 1 }
    counter.bind_typed("dec", Int32) { |n| n - 1 }
  end
end
