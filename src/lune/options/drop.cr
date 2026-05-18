module Lune
  class Options
    # File drop options, configured via `opts.drop { |d| ... }`.
    #
    # ```
    # Lune.run(app) do |opts|
    #   opts.drop do |d|
    #     d.zone    = "--lune-drop-target"
    #     d.on_drop = ->(x : Int32, y : Int32, paths : Array(String)) { puts paths.inspect; nil }
    #   end
    # end
    # ```
    class Drop
      # Disables the webview's built-in drag handling globally.
      # Prevents files from accidentally opening or navigating in the webview.
      # Enable the `file_drop` capability in lune.yml to receive drops in your app.
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
