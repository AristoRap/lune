module Lune
  class Options
    # File drop options, configured via `opts.file_drop { |fd| ... }`.
    #
    # ```
    # Lune.run(app) do |opts|
    #   opts.file_drop do |fd|
    #     fd.zone = "--lune-drop-target"
    #     fd.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) { puts paths.inspect; nil }
    #   end
    # end
    # ```
    class FileDrop
      # Disables the webview's built-in drag handling globally.
      # Prevents files from accidentally opening or navigating in the webview.
      # Enable the `file_drop` plugin in lune.yml to receive drops in your app.
      property disable_webview_drop : Bool = false

      # CSS custom property that marks an element as a drop zone.
      # e.g. "--lune-drop-target". Elements with this property set to `value`
      # receive the class `lune-drop-target-active` while a file is dragged over them.
      property zone : String = ""

      # CSS value that activates drop zone highlighting. Defaults to "drop".
      property value : String = "drop"

      # Crystal-side callback fired on drop. Receives (x, y, paths).
      property on_drop : ((Int32, Int32, Array(String)) -> Nil)? = nil

      def initialize; end
    end
  end
end
