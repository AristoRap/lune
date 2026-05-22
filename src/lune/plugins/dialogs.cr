module Lune
  module Plugins
    class Dialogs < Lune::Plugin
      include Lune::Bindable

      DESCRIPTOR = Descriptor.new(id: :dialogs, label: "Dialogs")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @[Lune::Bind]
      def open_file(prompt : String) : String
        Lune::Native::Dialogs.open_file(prompt) || ""
      end

      @[Lune::Bind]
      def open_dir(prompt : String) : String
        Lune::Native::Dialogs.open_dir(prompt) || ""
      end

      @[Lune::Bind]
      def open_files(prompt : String) : Array(String)
        Lune::Native::Dialogs.open_files(prompt)
      end

      @[Lune::Bind]
      def save_file(prompt : String, filename : String) : String
        Lune::Native::Dialogs.save_file(prompt, filename) || ""
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
