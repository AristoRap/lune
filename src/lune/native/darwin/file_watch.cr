{% if flag?(:darwin) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      EVFILT_VNODE =         -4_i16
      NOTE_DELETE  = 0x00000001_u32
      NOTE_WRITE   = 0x00000002_u32
      NOTE_ATTRIB  = 0x00000008_u32
      NOTE_RENAME  = 0x00000020_u32
      O_EVTONLY    =         0x8000

      class FileWatch
        @mu = Mutex.new
        @kq : Int32 = -1
        @watch_fds = {} of String => Int32

        def start(&on_event : String, String -> Nil) : Nil
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
          emit = on_event

          Fiber::ExecutionContext::Isolated.new("lune-file-watch") do
            events = StaticArray(LibC::Kevent, 32).new { LibC::Kevent.new }
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
                emit.call(path, kind)
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
      end
    end
  end
{% end %}
