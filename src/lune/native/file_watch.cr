module Lune
  module Native
    # Public surface assembled in sibling files:
    #   - mock/file_watch.cr    FileWatch with no-op methods (test mode)
    #   - darwin/file_watch.cr  kqueue NOTE_* + EVFILT_VNODE + FileWatch impl
    #   - linux/file_watch.cr   LibInotify + WatchMap + FileWatch impl
    #   - win32/file_watch.cr   NotImplementedError stubs (v0.10.0 backlog)
    #
    # The shared declaration (mutex + debounce helper) sits here; each per-OS
    # file reopens FileWatch to add platform ivars and method bodies.
    class FileWatch
      @mu = Mutex.new

      private def maybe_emit(
        app : Lune::App,
        path : String,
        kind : String,
        debounce : Time::Span,
        last_fired : Hash(String, Time::Instant),
      ) : Nil
        now = Time.instant
        return if (prev = last_fired[path]?) && (now - prev) < debounce
        last_fired[path] = now
        app.events.emit("file_watch", {"path" => path, "kind" => kind})
      end
    end
  end
end
