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
  opts.mac.full_size_content = true
  opts.drag_zone = "--lune-draggable"
  opts.disable_context_menu = true

  opts.enable_file_drop = true
  opts.drop_zone = "--lune-drop-target"

  opts.on_tray_click = -> { app.emit("trayEvent", "click") }
  opts.on_menu_click = ->(id : String) { app.emit("trayEvent", id) }
end
