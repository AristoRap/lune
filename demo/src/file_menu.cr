class FileMenu < Lune::Options::Menu::Group
  getter clock_paused : Bool = false
  @pause_item : Lune::Options::Menu::Item? = nil

  def initialize(@app : Lune::App)
    super("File")
    @pause_item = item("Pause Clock", shortcut: "cmd+p") { toggle_clock }
    separator
    item("Reload", shortcut: "cmd+r") { @app.eval("location.reload()") }
    separator
    item("Quit", shortcut: "cmd+q") { @app.eval("runtime.quit()") }
  end

  private def toggle_clock
    @clock_paused = !@clock_paused
    @pause_item.not_nil!.label = @clock_paused ? "Resume Clock" : "Pause Clock"
    @app.update_menu
    @app.event.emit("clockPaused", @clock_paused)
  end
end
