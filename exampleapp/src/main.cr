require "./demo"
require "lune"

app = Lune::App.new
app.install(Demo.new)

# ping → pong relay
app.on("ping") do |data|
  app.emit("pong", data)
end

# Shared state between the clock fiber and the menu callback.
clock_paused = false
pause_item : Lune::MenuItem? = nil

app.async("clock") do
  loop do
    app.emit("tick", Time.utc.to_rfc3339) unless clock_paused
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

    m.submenu "File" do |file|
      # Keep the returned MenuItem so we can mutate its label at runtime.
      pause_item = file.item("Pause Clock", shortcut: "cmd+p") do
        clock_paused = !clock_paused
        if item = pause_item
          item.label = clock_paused ? "Resume Clock" : "Pause Clock"
          app.update_menu
        end
        app.emit("clockPaused", clock_paused)
      end

      file.separator
      file.item("Reload", shortcut: "cmd+r") { app.eval("location.reload()") }
      file.separator
      file.item("Quit", shortcut: "cmd+q") { app.eval("runtime.quit()") }
    end

    m.edit_menu

    m.submenu "View" do |view|
      view.item("Zoom In")     { app.eval("document.body.style.zoom = (Math.round((parseFloat(document.body.style.zoom || '1') + 0.1) * 10) / 10).toString()") }
      view.item("Zoom Out")    { app.eval("document.body.style.zoom = (Math.round((Math.max(0.5, parseFloat(document.body.style.zoom || '1') - 0.1)) * 10) / 10).toString()") }
      view.item("Actual Size", shortcut: "cmd+0") { app.eval("document.body.style.zoom = '1'") }
    end
  end
end
