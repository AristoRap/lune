module Lune
  class Options
    # Window drag-handle options, configured via `opts.drag { |d| ... }`.
    #
    # ```
    # Lune.run(app) do |opts|
    #   opts.drag do |d|
    #     d.zone = "--lune-draggable"
    #   end
    # end
    # ```
    class Drag
      # CSS custom property name that marks an element as a window drag handle.
      # When non-empty, any element with this property set to `value` (and its
      # descendants) can be used to drag the window. Example: `"--lune-draggable"`.
      property zone : String = ""

      # CSS value that activates drag behaviour. Defaults to `"drag"`.
      property value : String = "drag"

      def initialize; end
    end
  end
end
