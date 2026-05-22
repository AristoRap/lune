{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      class FileWatch
        def start(app : Lune::App, debounce : Time::Span = 50.milliseconds) : Nil
          raise NotImplementedError.new("Lune::Native::FileWatch is not implemented on Windows yet (v0.10.0 backlog — will use ReadDirectoryChangesW). Exclude the `file_watch` capability in lune.yml to silence this.")
        end

        def add_watch(path : String) : Nil
          raise NotImplementedError.new("Lune::Native::FileWatch is not implemented on Windows yet (v0.10.0 backlog)")
        end

        def remove_watch(path : String) : Nil
          raise NotImplementedError.new("Lune::Native::FileWatch is not implemented on Windows yet (v0.10.0 backlog)")
        end

        def stop : Nil; end
      end
    end
  end
{% end %}
