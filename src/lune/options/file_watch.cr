module Lune
  class Options
    # FileWatch options, configured via `opts.file_watch { |fw| ... }`.
    #
    # ```
    # Lune.run(app) do |opts|
    #   opts.file_watch do |fw|
    #     fw.debounce = 100.milliseconds
    #   end
    # end
    # ```
    class FileWatch
      # Minimum time between emitted events for the same path.
      # Suppresses OS-level noise (editors write temp files, rename, delete) so
      # the frontend receives one logical event per save. Defaults to 50ms.
      property debounce : Time::Span = 50.milliseconds

      def initialize; end
    end
  end
end
