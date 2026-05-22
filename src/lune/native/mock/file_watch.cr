{% if flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      class FileWatch
        def start(&on_event : String, String -> Nil) : Nil; end

        def add_watch(path : String) : Nil; end

        def remove_watch(path : String) : Nil; end

        def stop : Nil; end
      end
    end
  end
{% end %}
