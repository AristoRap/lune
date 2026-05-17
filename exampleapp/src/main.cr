require "./demo"
require "./file_menu"
require "lune"

app = Lune::App.new
app.install(Demo.new)

# ping → pong relay
app.on("ping") do |data|
  app.emit("pong", data)
end

# Class-based style: state and callbacks live inside the menu class.
file_menu = FileMenu.new(app)

app.async("clock") do
  loop do
    app.emit("tick", Time.utc.to_rfc3339) unless file_menu.clock_paused
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

  opts.menu do |m|
    m.app_menu
    m.submenu file_menu                          # class-based: Group subclass

    m.edit_menu

    m.submenu "View" do |view|                   # block style: inline, no state needed
      view.item("Zoom In")     { app.eval("document.body.style.zoom = (Math.round((parseFloat(document.body.style.zoom || '1') + 0.1) * 10) / 10).toString()") }
      view.item("Zoom Out")    { app.eval("document.body.style.zoom = (Math.round((Math.max(0.5, parseFloat(document.body.style.zoom || '1') - 0.1)) * 10) / 10).toString()") }
      view.item("Actual Size", shortcut: "cmd+0") { app.eval("document.body.style.zoom = '1'") }
    end
  end
end
