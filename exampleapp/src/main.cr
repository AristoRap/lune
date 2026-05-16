require "./demo"
require "lune"

app = Lune::App.new
app.install(Demo.new)

# ping → pong relay
app.on("ping") do |data|
  app.emit("pong", data)
end

# live clock
app.async("clock") do
  loop do
    app.emit("tick", Time.utc.to_rfc3339)
    sleep 1.second
  end
end

Lune.run(app, assets: "frontend/dist") do |opts|
  opts.title = "Lune Example"
  opts.width = 1100
  opts.height = 740
  opts.disable_context_menu = true

  opts.mac do |m|
    m.full_size_content = true
  end

  opts.drag do |d|
    d.zone = "--lune-draggable"
  end

  opts.drop do |d|
    d.enabled = true
    d.zone = "--lune-drop-target"
  end

  opts.tray do |t|
    t.on_click      = -> { app.emit("trayEvent", "click") }
    t.on_menu_click = ->(id : String) { app.emit("trayEvent", id) }
  end
end
