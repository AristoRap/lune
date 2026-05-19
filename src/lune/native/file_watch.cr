module Lune
  module Native
    {% if flag?(:darwin) %}
      EVFILT_VNODE = -4_i16
      NOTE_DELETE  = 0x00000001_u32
      NOTE_WRITE   = 0x00000002_u32
      NOTE_ATTRIB  = 0x00000008_u32
      NOTE_RENAME  = 0x00000020_u32
      O_EVTONLY    = 0x8000
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
          wd     : LibC::Int
          mask   : LibC::UInt
          cookie : LibC::UInt
          len    : LibC::UInt
        end

        fun inotify_init : LibC::Int
        fun inotify_add_watch(fd : LibC::Int, path : LibC::Char*, mask : LibC::UInt) : LibC::Int
        fun inotify_rm_watch(fd : LibC::Int, wd : LibC::Int) : LibC::Int
      end
    {% end %}

    class FileWatch
      @mu = Mutex.new

      {% if flag?(:darwin) %}
        @kq : Int32 = -1
        @watch_fds = {} of String => Int32
      {% elsif flag?(:linux) %}
        @inotify_fd : Int32 = -1
        @watch_ids  = {} of Int32 => String
        @path_to_wd = {} of String => Int32
      {% end %}

      {% if flag?(:lune_native_test_mock) %}
        def start(app : Lune::App) : Nil; end
        def add_watch(path : String) : Nil; end
        def remove_watch(path : String) : Nil; end
        def stop : Nil; end

      {% elsif flag?(:darwin) %}
        def start(app : Lune::App) : Nil
          return if @mu.synchronize { @kq >= 0 }
          kq = LibC.kqueue
          if kq < 0
            Lune.logger.warn { "FileWatch: kqueue() failed — file watching disabled" }
            return
          end
          @mu.synchronize { @kq = kq }

          kq_val    = kq
          mu        = @mu
          watch_fds = @watch_fds

          Fiber::ExecutionContext::Isolated.new("lune-file-watch") do
            events = StaticArray(LibC::Kevent, 32).new { LibC::Kevent.new }
            loop do
              n = LibC.kevent(kq_val, Pointer(LibC::Kevent).null, 0, events.to_unsafe, 32, Pointer(LibC::Timespec).null)
              break if n < 0
              n.times do |i|
                ev     = events[i]
                fd     = ev.ident.to_i32
                fflags = ev.fflags
                path   = mu.synchronize { watch_fds.key_for?(fd) }
                next unless path
                kind = if fflags & NOTE_DELETE != 0
                         "deleted"
                       elsif fflags & NOTE_RENAME != 0
                         "renamed"
                       else
                         "modified"
                       end
                app.emit("file_watch", {"path" => path, "kind" => kind})
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
            @watch_fds[path] = fd
            ev = LibC::Kevent.new
            ev.ident  = fd.to_u64
            ev.filter = EVFILT_VNODE
            ev.flags  = LibC::EV_ADD | LibC::EV_CLEAR
            ev.fflags = NOTE_DELETE | NOTE_WRITE | NOTE_ATTRIB | NOTE_RENAME
            ev.data   = 0
            ev.udata  = Pointer(Void).null
            LibC.kevent(@kq, pointerof(ev), 1, Pointer(LibC::Kevent).null, 0, Pointer(LibC::Timespec).null)
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
        def start(app : Lune::App) : Nil
          return if @mu.synchronize { @inotify_fd >= 0 }
          ifd = LibInotify.inotify_init
          if ifd < 0
            Lune.logger.warn { "FileWatch: inotify_init() failed — file watching disabled" }
            return
          end
          @mu.synchronize { @inotify_fd = ifd }

          ifd_val   = ifd
          mu        = @mu
          watch_ids = @watch_ids

          Fiber::ExecutionContext::Isolated.new("lune-file-watch") do
            buf = Bytes.new(4096)
            loop do
              n = LibC.read(ifd_val, buf.to_unsafe.as(Void*), buf.size)
              break if n <= 0
              offset = 0
              while offset < n
                ev   = buf.to_unsafe.as(LibInotify::InotifyEvent*).value
                wd   = ev.wd
                path = mu.synchronize { watch_ids[wd]? }
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
                  app.emit("file_watch", {"path" => path, "kind" => kind})
                end
                offset += sizeof(LibInotify::InotifyEvent) + ev.len
                buf = buf[sizeof(LibInotify::InotifyEvent) + ev.len..]
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
            return if @path_to_wd.has_key?(path)
            wd = LibInotify.inotify_add_watch(@inotify_fd, path, mask)
            if wd < 0
              Lune.logger.warn { "FileWatch: cannot watch #{path}" }
              return
            end
            @watch_ids[wd]  = path
            @path_to_wd[path] = wd
          end
        end

        def remove_watch(path : String) : Nil
          @mu.synchronize do
            wd = @path_to_wd.delete(path)
            if wd
              @watch_ids.delete(wd)
              LibInotify.inotify_rm_watch(@inotify_fd, wd)
            end
          end
        end

        def stop : Nil
          ifd = @mu.synchronize { fd = @inotify_fd; @inotify_fd = -1; fd }
          if ifd >= 0
            LibC.close(ifd)
            @mu.synchronize do
              @watch_ids.clear
              @path_to_wd.clear
            end
          end
        end

      {% else %}
        def start(app : Lune::App) : Nil; end
        def add_watch(path : String) : Nil; end
        def remove_watch(path : String) : Nil; end
        def stop : Nil; end
      {% end %}
    end
  end
end
