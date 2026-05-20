require "./demo"
require "./file_menu"
require "lune"

app = Lune::App.new
app.install(Demo.new)

# ping → pong relay
app.events.on("ping") do |data|
  app.events.emit("pong", data)
end

# Class-based style: state and callbacks live inside the menu class.
file_menu = FileMenu.new(app)

app.async("clock") do
  loop do
    app.events.emit("tick", Time.utc.to_rfc3339) unless file_menu.clock_paused
    sleep 1.second
  end
end

# ----------------------------
# Stream — high-throughput IPC demo
# ----------------------------

streaming = Atomic(Int32).new(0)

app.stream.on("stream-start") { |_| streaming.set(1) }
app.stream.on("stream-stop") { |_| streaming.set(0) }
app.stream.on("stream-ping") { |data| app.stream.send("stream-pong", data) }

prices = {"BTC" => 45000.0_f64, "ETH" => 2800.0_f64, "SOL" => 120.0_f64, "AAPL" => 185.0_f64, "MSFT" => 380.0_f64}
syms = prices.keys

app.async("ticker") do
  loop do
    if streaming.get == 1
      sym = syms.sample
      delta = (Random.rand - 0.5) * prices[sym] * 0.002
      prices[sym] = (prices[sym] + delta).round(2)
      app.stream.send("tick", {"symbol" => sym, "price" => prices[sym], "change" => delta.round(4)})
      sleep 50.milliseconds
    else
      sleep 100.milliseconds
    end
  end
end

Lune.run(app, assets: "frontend/dist") do |opts|
  opts.title = "Lune Example"
  opts.width = 1100
  opts.height = 740
  # opts.on_window_ready = ->(_handle : Void*) {
  #   puts "Window open, about to navigate"
  # }
  # opts.disable_context_menu = true
  opts.devtools = {{ flag?(:lune_dev) }}

  opts.mac do |m|
    m.full_size_content = true
    # m.hide_traffic_lights = true
    # Menubar-only mode: hides the dock icon, starts the window hidden, and
    # auto-hides on focus loss. The tray icon shows at boot automatically.
    # Click behavior is configured separately via `opts.tray.toggle_window_on`
    # (e.g. `[:left_click]` for popover-style apps) — leave it empty for
    # Docker-style apps where the menu is the only interaction.
    # m.menubar_mode = true
  end

  # opts.tray do |t|
  #   t.toggle_window_on = [:left_click] # popover-style: left-click drops the window
  # end

  opts.drag do |d|
    d.zone = "--lune-draggable"
  end

  opts.file_drop do |fd|
    fd.zone = "--lune-drop-target"
  end

  opts.menu do |m|
    m.app_menu
    m.submenu file_menu # class-based: Group subclass

    m.edit_menu

    m.submenu "View" do |view| # block style: inline, no state needed
      view.item("Zoom In") { app.eval("document.body.style.zoom = (Math.round((parseFloat(document.body.style.zoom || '1') + 0.1) * 10) / 10).toString()") }
      view.item("Zoom Out") { app.eval("document.body.style.zoom = (Math.round((Math.max(0.5, parseFloat(document.body.style.zoom || '1') - 0.1)) * 10) / 10).toString()") }
      view.item("Actual Size", shortcut: "cmd+0") { app.eval("document.body.style.zoom = '1'") }
    end
  end
end
