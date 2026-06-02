module Lune
  module Plugins
    class Dialogs < Lune::Plugin
      include Lune::Bindable

      DESCRIPTOR = Descriptor.new(id: :dialogs, label: "Dialogs")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      # File-type filter: `[{name: "Images", extensions: ["png", "jpg"]}]`. JS
      # callers pass an array of `{name, extensions}` objects directly; vow
      # decodes it into this NamedTuple and maps it to the matching TS shape
      # (`{ name: string; extensions: string[] }[]`). Empty / omitted = no
      # filtering. Applied per-platform: Win32 via `lpstrFilter`, macOS via
      # `allowedFileTypes`, Linux via `GtkFileFilter.add_pattern`.
      alias FileFilter = NamedTuple(name: String, extensions: Array(String))

      @[Lune::Bind]
      def open_file(prompt : String, filters : Array(FileFilter) = [] of FileFilter) : String
        Lune::Native::Dialogs.open_file(prompt, filters) || ""
      end

      @[Lune::Bind]
      def open_dir(prompt : String) : String
        Lune::Native::Dialogs.open_dir(prompt) || ""
      end

      @[Lune::Bind]
      def open_files(prompt : String, filters : Array(FileFilter) = [] of FileFilter) : Array(String)
        Lune::Native::Dialogs.open_files(prompt, filters)
      end

      @[Lune::Bind]
      def save_file(prompt : String, filename : String, filters : Array(FileFilter) = [] of FileFilter) : String
        Lune::Native::Dialogs.save_file(prompt, filename, filters) || ""
      end

      @[Lune::Bind]
      def message_info(title : String, message : String) : Nil
        Lune::Native::Dialogs.message(0, title, message)
      end

      @[Lune::Bind]
      def message_warning(title : String, message : String) : Nil
        Lune::Native::Dialogs.message(1, title, message)
      end

      @[Lune::Bind]
      def message_error(title : String, message : String) : Nil
        Lune::Native::Dialogs.message(2, title, message)
      end

      @[Lune::Bind]
      def message_question(title : String, message : String) : String
        Lune::Native::Dialogs.message(3, title, message)
      end
    end
  end
end
