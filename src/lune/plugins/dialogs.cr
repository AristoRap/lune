module Lune
  module Plugins
    class Dialogs < Lune::Plugin
      include Lune::Bindable

      DESCRIPTOR = Descriptor.new(id: :dialogs, label: "Dialogs")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      # File-type filter shape: `[{name: "Images", extensions: ["png", "jpg"]}]`.
      # JS callers pass an array of `{name, extensions}` objects; the BindOverride
      # below stringifies it on the JS side and the Crystal side parses it back.
      # Empty / omitted = no filtering (the picker shows every file). Filters
      # are applied per-platform: Win32 via `lpstrFilter`, macOS via
      # `allowedFileTypes`, Linux via `GtkFileFilter.add_pattern`.
      alias FileFilter = NamedTuple(name: String, extensions: Array(String))

      private def parse_filters(json : String) : Array(FileFilter)
        return [] of FileFilter if json.empty? || json == "[]"
        raw = Array(Hash(String, JSON::Any)).from_json(json)
        raw.compact_map do |h|
          name = h["name"]?.try(&.as_s?) || ""
          exts = h["extensions"]?.try(&.as_a?).try(&.compact_map(&.as_s?)) || [] of String
          next if exts.empty?
          {name: name, extensions: exts}
        end
      rescue ex : JSON::ParseException
        Lune.logger.warn { "Dialogs: invalid filters JSON — #{ex.message}" }
        [] of FileFilter
      end

      @[Lune::Bind]
      @[Lune::BindOverride(
        arg_names: ["prompt", "filters"],
        arg_transforms: [nil, "JSON.stringify(filters || [])"] of String?,
        ts_args: [nil, "{ name: string; extensions: string[] }[]"] of String?,
      )]
      def open_file(prompt : String, filters_json : String = "[]") : String
        Lune::Native::Dialogs.open_file(prompt, parse_filters(filters_json)) || ""
      end

      @[Lune::Bind]
      def open_dir(prompt : String) : String
        Lune::Native::Dialogs.open_dir(prompt) || ""
      end

      @[Lune::Bind]
      @[Lune::BindOverride(
        arg_names: ["prompt", "filters"],
        arg_transforms: [nil, "JSON.stringify(filters || [])"] of String?,
        ts_args: [nil, "{ name: string; extensions: string[] }[]"] of String?,
      )]
      def open_files(prompt : String, filters_json : String = "[]") : Array(String)
        Lune::Native::Dialogs.open_files(prompt, parse_filters(filters_json))
      end

      @[Lune::Bind]
      @[Lune::BindOverride(
        arg_names: ["prompt", "filename", "filters"],
        arg_transforms: [nil, nil, "JSON.stringify(filters || [])"] of String?,
        ts_args: [nil, nil, "{ name: string; extensions: string[] }[]"] of String?,
      )]
      def save_file(prompt : String, filename : String, filters_json : String = "[]") : String
        Lune::Native::Dialogs.save_file(prompt, filename, parse_filters(filters_json)) || ""
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
