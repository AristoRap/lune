module Lune
  module Native
    {% if flag?(:darwin) %}
      EVFILT_VNODE =         -4_i16
      NOTE_DELETE  = 0x00000001_u32
      NOTE_WRITE   = 0x00000002_u32
      NOTE_ATTRIB  = 0x00000008_u32
      NOTE_RENAME  = 0x00000020_u32
      O_EVTONLY    =         0x8000
    {% elsif flag?(:linux) %}
      lib LibInotify
        IN_MODIFY      = 0x00000002_u32
        IN_ATTRIB      = 0x00000004_u32
        IN_MOVED_FROM  = 0x00000040_u32
        IN_MOVED_TO    = 0x00000080_u32
        IN_CREATE      = 0x00000100_u32
        IN_DELETE      = 0x00000200_u32
        IN_DELETE_SELF = 0x00000400_u32
        IN_MOVE_SELF   = 0x00000800_u32

        struct InotifyEvent
          wd : LibC::Int
          mask : LibC::UInt
          cookie : LibC::UInt
          len : LibC::UInt
        end

        fun inotify_init : LibC::Int
        fun inotify_add_watch(fd : LibC::Int, path : LibC::Char*, mask : LibC::UInt) : LibC::Int
        fun inotify_rm_watch(fd : LibC::Int, wd : LibC::Int) : LibC::Int
      end
    {% end %}

    # Bidirectional watch registry for Linux inotify (wd ↔ path).
    # Encapsulates the two maps so they are always updated as a unit.
    private class WatchMap
      def initialize
        @by_wd = {} of Int32 => String
        @by_path = {} of String => Int32
      end

      def add(path : String, wd : Int32) : Nil
        @by_wd[wd] = path
        @by_path[path] = wd
      end

      def remove(path : String) : Int32?
        if wd = @by_path.delete(path)
          @by_wd.delete(wd)
          wd
        end
      end

      def path_for(wd : Int32) : String?
        @by_wd[wd]?
      end

      def includes?(path : String) : Bool
        @by_path.has_key?(path)
      end

      def clear : Nil
        @by_wd.clear
        @by_path.clear
      end
    end

    class FileWatch
      @mu = Mutex.new

      {% if flag?(:darwin) %}
        @kq : Int32 = -1
        @watch_fds = {} of String => Int32
      {% elsif flag?(:linux) %}
        @inotify_fd : Int32 = -1
        @watches = WatchMap.new
      {% end %}

      {% if flag?(:lune_native_test_mock) %}
        def start(app : Lune::App, debounce : Time::Span = 50.milliseconds) : Nil; end

        def add_watch(path : String) : Nil; end

        def remove_watch(path : String) : Nil; end

        def stop : Nil; end
      {% elsif flag?(:darwin) %}
        def start(app : Lune::App, debounce : Time::Span = 50.milliseconds) : Nil
          return if @mu.synchronize { @kq >= 0 }
          kq = LibC.kqueue
          if kq < 0
            Lune.logger.warn { "FileWatch: kqueue() failed — file watching disabled" }
            return
          end
          @mu.synchronize { @kq = kq }

          kq_val = kq
          mu = @mu
          watch_fds = @watch_fds

          Fiber::ExecutionContext::Isolated.new("lune-file-watch") do
            events = StaticArray(LibC::Kevent, 32).new { LibC::Kevent.new }
            last_fired = {} of String => Time::Instant
            loop do
              n = LibC.kevent(kq_val, Pointer(LibC::Kevent).null, 0, events.to_unsafe, 32, Pointer(LibC::Timespec).null)
              break if n < 0
              n.times do |i|
                ev = events[i]
                fd = ev.ident.to_i32
                fflags = ev.fflags
                path = mu.synchronize { watch_fds.key_for?(fd) }
                next unless path
                kind = if fflags & NOTE_DELETE != 0
                         "deleted"
                       elsif fflags & NOTE_RENAME != 0
                         "renamed"
                       else
                         "modified"
                       end
                maybe_emit(app, path, kind, debounce, last_fired)
              end
            end
          end
        end

        def add_watch(path : String) : Nil
          @mu.synchronize do
            return if @watch_fds.has_key?(path)
            fd = LibC.open(path, O_EVTONLY, 0)
            if fd < 0
              Lune.logger.warn { "FileWatch: cannot open #{path}" }
              return
            end
            ev = LibC::Kevent.new
            ev.ident = fd.to_u64
            ev.filter = EVFILT_VNODE
            ev.flags = LibC::EV_ADD | LibC::EV_CLEAR
            ev.fflags = NOTE_DELETE | NOTE_WRITE | NOTE_ATTRIB | NOTE_RENAME
            ev.data = 0
            ev.udata = Pointer(Void).null
            if LibC.kevent(@kq, pointerof(ev), 1, Pointer(LibC::Kevent).null, 0, Pointer(LibC::Timespec).null) < 0
              LibC.close(fd)
              Lune.logger.warn { "FileWatch: kevent registration failed for #{path}" }
              return
            end
            @watch_fds[path] = fd
          end
        end

        def remove_watch(path : String) : Nil
          @mu.synchronize do
            fd = @watch_fds.delete(path)
            LibC.close(fd) if fd
          end
        end

        def stop : Nil
          kq = @mu.synchronize { fd = @kq; @kq = -1; fd }
          if kq >= 0
            LibC.close(kq)
            @mu.synchronize do
              @watch_fds.each_value { |fd| LibC.close(fd) }
              @watch_fds.clear
            end
          end
        end
      {% elsif flag?(:linux) %}
        def start(app : Lune::App, debounce : Time::Span = 50.milliseconds) : Nil
          return if @mu.synchronize { @inotify_fd >= 0 }
          ifd = LibInotify.inotify_init
          if ifd < 0
            Lune.logger.warn { "FileWatch: inotify_init() failed — file watching disabled" }
            return
          end
          @mu.synchronize { @inotify_fd = ifd }

          ifd_val = ifd
          mu = @mu
          watches = @watches

          Fiber::ExecutionContext::Isolated.new("lune-file-watch") do
            buf = Bytes.new(4096)
            last_fired = {} of String => Time::Instant
            loop do
              n = LibC.read(ifd_val, buf.to_unsafe.as(Void*), buf.size)
              break if n <= 0
              offset = 0
              while offset < n
                event_size = sizeof(LibInotify::InotifyEvent)
                break if buf.size < event_size
                ev = buf.to_unsafe.as(LibInotify::InotifyEvent*).value
                wd = ev.wd
                name_len = ev.len.to_i
                step = event_size + name_len
                break if step > buf.size
                path = mu.synchronize { watches.path_for(wd) }
                if path
                  mask = ev.mask
                  kind = if mask & (LibInotify::IN_DELETE | LibInotify::IN_DELETE_SELF) != 0
                           "deleted"
                         elsif mask & (LibInotify::IN_MOVED_FROM | LibInotify::IN_MOVED_TO | LibInotify::IN_MOVE_SELF) != 0
                           "renamed"
                         elsif mask & LibInotify::IN_CREATE != 0
                           "created"
                         else
                           "modified"
                         end
                  maybe_emit(app, path, kind, debounce, last_fired)
                end
                offset += step
                buf = buf[step..]
              end
              buf = Bytes.new(4096)
            end
          end
        end

        def add_watch(path : String) : Nil
          mask = LibInotify::IN_MODIFY | LibInotify::IN_ATTRIB |
                 LibInotify::IN_CREATE | LibInotify::IN_DELETE |
                 LibInotify::IN_DELETE_SELF | LibInotify::IN_MOVED_FROM |
                 LibInotify::IN_MOVED_TO | LibInotify::IN_MOVE_SELF
          @mu.synchronize do
            return if @watches.includes?(path)
            wd = LibInotify.inotify_add_watch(@inotify_fd, path, mask)
            if wd < 0
              Lune.logger.warn { "FileWatch: cannot watch #{path}" }
              return
            end
            @watches.add(path, wd)
          end
        end

        def remove_watch(path : String) : Nil
          @mu.synchronize do
            if wd = @watches.remove(path)
              LibInotify.inotify_rm_watch(@inotify_fd, wd)
            end
          end
        end

        def stop : Nil
          ifd = @mu.synchronize { fd = @inotify_fd; @inotify_fd = -1; fd }
          if ifd >= 0
            LibC.close(ifd)
            @mu.synchronize { @watches.clear }
          end
        end
      {% else %}
        def start(app : Lune::App, debounce : Time::Span = 50.milliseconds) : Nil; end

        def add_watch(path : String) : Nil; end

        def remove_watch(path : String) : Nil; end

        def stop : Nil; end
      {% end %}

      private def maybe_emit(
        app : Lune::App,
        path : String,
        kind : String,
        debounce : Time::Span,
        last_fired : Hash(String, Time::Instant)
      ) : Nil
        now = Time.instant
        return if (prev = last_fired[path]?) && (now - prev) < debounce
        last_fired[path] = now
        app.emit("file_watch", {"path" => path, "kind" => kind})
      end
    end
  end
end
