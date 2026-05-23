{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      # Win32 file watching via ReadDirectoryChangesW + IOCP. One handle per
      # watched path (opened on the parent dir when the path is a file, the
      # dir itself when it's a directory). A single Isolated pump fiber owns
      # the IOCP and dispatches completions back to the user's `on_event`
      # closure synchronously — matches the macOS/Linux model of one pump +
      # one shared callback.
      #
      # CreateFileW / CloseHandle / CreateIoCompletionPort /
      # PostQueuedCompletionStatus / CancelIoEx are already declared in
      # Crystal's stdlib LibC for Windows; only ReadDirectoryChangesW and the
      # single-completion GetQueuedCompletionStatus are added here.
      @[Link("kernel32")]
      lib LibKernel32FileWatch
        FILE_NOTIFY_CHANGE_FILE_NAME  = 0x00000001_u32
        FILE_NOTIFY_CHANGE_DIR_NAME   = 0x00000002_u32
        FILE_NOTIFY_CHANGE_ATTRIBUTES = 0x00000004_u32
        FILE_NOTIFY_CHANGE_SIZE       = 0x00000008_u32
        FILE_NOTIFY_CHANGE_LAST_WRITE = 0x00000010_u32
        FILE_NOTIFY_CHANGE_CREATION   = 0x00000040_u32

        FILE_ACTION_ADDED            = 0x00000001_u32
        FILE_ACTION_REMOVED          = 0x00000002_u32
        FILE_ACTION_MODIFIED         = 0x00000003_u32
        FILE_ACTION_RENAMED_OLD_NAME = 0x00000004_u32
        FILE_ACTION_RENAMED_NEW_NAME = 0x00000005_u32

        # Layout-only struct: `FileName : WCHAR[1]` flexes past the end of
        # the declared size, so we always read bytes after `file_name_length`
        # via raw pointer arithmetic.
        struct FileNotifyInformation
          next_entry_offset : UInt32
          action : UInt32
          file_name_length : UInt32
        end

        fun read_directory_changes_w = ReadDirectoryChangesW(
          dir_handle : Void*,
          buffer : Void*,
          buffer_length : UInt32,
          watch_subtree : LibC::BOOL,
          notify_filter : UInt32,
          bytes_returned : UInt32*,
          overlapped : LibC::OVERLAPPED*,
          completion_routine : Void*,
        ) : LibC::BOOL

        fun get_queued_completion_status = GetQueuedCompletionStatus(
          port : Void*,
          bytes : UInt32*,
          completion_key : LibC::ULONG_PTR*,
          overlapped : LibC::OVERLAPPED**,
          timeout : UInt32,
        ) : LibC::BOOL
      end

      class FileWatch
        # 4 KB per watch — fits dozens of FILE_NOTIFY_INFORMATION records.
        # On overflow the kernel returns 0 bytes; we re-arm and the change is
        # lost (matches darwin/linux's best-effort posture).
        BUF_SIZE = 4096_u32

        # Watched events. Mirrors the inotify mask in linux/file_watch.cr.
        NOTIFY_FILTER = LibKernel32FileWatch::FILE_NOTIFY_CHANGE_FILE_NAME |
                        LibKernel32FileWatch::FILE_NOTIFY_CHANGE_DIR_NAME |
                        LibKernel32FileWatch::FILE_NOTIFY_CHANGE_ATTRIBUTES |
                        LibKernel32FileWatch::FILE_NOTIFY_CHANGE_SIZE |
                        LibKernel32FileWatch::FILE_NOTIFY_CHANGE_LAST_WRITE |
                        LibKernel32FileWatch::FILE_NOTIFY_CHANGE_CREATION

        # GQCS sentinel posted by `stop`. Legitimate completions always carry
        # an OVERLAPPED*, so null overlapped uniquely signals shutdown.
        STOP_KEY = 0_u64

        # One entry per watched path. The OVERLAPPED + buffer pointers are
        # heap-allocated and reachable from `@watches`, so the GC keeps them
        # alive across the async ReadDirectoryChangesW call.
        private class Entry
          getter path : String
          getter file_basename : String? # nil when the watched path is a dir
          getter handle : Void*
          getter overlapped : Pointer(LibC::OVERLAPPED)
          getter buffer : Pointer(UInt8)

          def initialize(@path, @file_basename, @handle, @overlapped, @buffer)
          end
        end

        @mu = Mutex.new
        @iocp : Void* = Pointer(Void).null
        @on_event : (String, String -> Nil)? = nil
        @watches = {} of String => Entry
        @by_overlapped = {} of UInt64 => Entry
        @started = false

        def start(&on_event : String, String -> Nil) : Nil
          return if @mu.synchronize { @started }

          # CreateIoCompletionPort with INVALID_HANDLE_VALUE + null existing
          # port creates an empty port we attach handles to later.
          invalid = Pointer(Void).new(0xFFFFFFFFFFFFFFFF_u64)
          # LibC binds completionKey as `ULong*` (stdlib quirk); the symbol
          # actually takes a ULONG_PTR by value. At the x64 ABI level a 64-bit
          # value in RCX/R8 is identical to a pointer there, so we pass null.
          port = LibC.CreateIoCompletionPort(
            invalid, Pointer(Void).null, Pointer(LibC::ULong).null, 0_u32)
          if port.null?
            Lune.logger.warn { "FileWatch: CreateIoCompletionPort failed — file watching disabled" }
            return
          end

          @mu.synchronize do
            @iocp = port
            @on_event = on_event
            @started = true
          end

          Fiber::ExecutionContext::Isolated.new("lune-file-watch") do
            run_pump(port)
          end
        end

        def add_watch(path : String) : Nil
          return unless @mu.synchronize { @started }

          # ReadDirectoryChangesW needs a directory HANDLE. When the user
          # passes a file path we open the parent and filter completions by
          # basename; a directory path opens the dir itself, basename nil.
          is_dir = File.directory?(path)
          dir = is_dir ? path : File.dirname(path)
          file_basename = is_dir ? nil : File.basename(path)

          unless File.directory?(dir)
            Lune.logger.warn { "FileWatch: parent dir does not exist: #{dir}" }
            return
          end

          path_w = wstr(dir)
          handle = LibC.CreateFileW(
            path_w,
            LibC::FILE_GENERIC_READ,
            LibC::FILE_SHARE_READ | LibC::FILE_SHARE_WRITE | LibC::FILE_SHARE_DELETE,
            Pointer(LibC::SECURITY_ATTRIBUTES).null,
            LibC::OPEN_EXISTING,
            LibC::FILE_FLAG_BACKUP_SEMANTICS | LibC::FILE_FLAG_OVERLAPPED,
            LibC::HANDLE.null,
          )

          if handle.address == 0xFFFFFFFFFFFFFFFF_u64
            Lune.logger.warn { "FileWatch: CreateFileW failed for #{dir}" }
            return
          end

          # Attach to our IOCP. The completionKey arg is ignored by us — we
          # identify entries by overlapped pointer instead — so we pass null.
          port_ret = LibC.CreateIoCompletionPort(
            handle, @iocp, Pointer(LibC::ULong).null, 1_u32)
          if port_ret.null? || port_ret != @iocp
            LibC.CloseHandle(handle)
            Lune.logger.warn { "FileWatch: CreateIoCompletionPort attach failed for #{dir}" }
            return
          end

          overlapped = Pointer(LibC::OVERLAPPED).malloc(1)
          buffer = Pointer(UInt8).malloc(BUF_SIZE)

          entry = Entry.new(path, file_basename, handle, overlapped, buffer)
          @mu.synchronize do
            # Replace any prior watch for the same path (close stale handle).
            if prev = @watches[path]?
              close_entry(prev)
              @by_overlapped.delete(prev.overlapped.address.to_u64)
            end
            @watches[path] = entry
            @by_overlapped[overlapped.address.to_u64] = entry
          end

          arm_read(entry)
        end

        def remove_watch(path : String) : Nil
          entry = @mu.synchronize do
            e = @watches.delete(path)
            if e
              @by_overlapped.delete(e.overlapped.address.to_u64)
            end
            e
          end
          close_entry(entry) if entry
        end

        def stop : Nil
          port, entries = @mu.synchronize do
            p = @iocp
            es = @watches.values
            @iocp = Pointer(Void).null
            @watches.clear
            @by_overlapped.clear
            @started = false
            @on_event = nil
            {p, es}
          end
          entries.each { |e| close_entry(e) }
          return if port.null?
          # Wake the pump's blocked GQCS so it can exit cleanly.
          LibC.PostQueuedCompletionStatus(
            port,
            0_u32,
            LibC::ULONG_PTR.new(STOP_KEY),
            Pointer(LibC::OVERLAPPED).null,
          )
          LibC.CloseHandle(port)
        end

        # ── private ────────────────────────────────────────────────────────

        private def wstr(s : String) : UInt16*
          arr = s.to_utf16
          buf = Pointer(UInt16).malloc(arr.size + 1)
          arr.size.times { |i| buf[i] = arr[i] }
          buf[arr.size] = 0_u16
          buf
        end

        private def close_entry(entry : Entry) : Nil
          LibC.CancelIoEx(entry.handle, entry.overlapped)
          LibC.CloseHandle(entry.handle)
        end

        private def arm_read(entry : Entry) : Nil
          bytes = 0_u32
          ok = LibKernel32FileWatch.read_directory_changes_w(
            entry.handle,
            entry.buffer.as(Void*),
            BUF_SIZE,
            0,             # watch_subtree = false (immediate children only)
            NOTIFY_FILTER,
            pointerof(bytes),
            entry.overlapped,
            Pointer(Void).null,
          )
          if ok == 0
            # ERROR_OPERATION_ABORTED is expected during teardown; log
            # otherwise so a misbehaving handle is visible.
            Lune.logger.warn { "FileWatch: ReadDirectoryChangesW failed for #{entry.path}" }
          end
        end

        private def run_pump(port : Void*) : Nil
          bytes = 0_u32
          key = LibC::ULONG_PTR.new(0)
          overlapped = Pointer(LibC::OVERLAPPED).null
          loop do
            ok = LibKernel32FileWatch.get_queued_completion_status(
              port,
              pointerof(bytes),
              pointerof(key),
              pointerof(overlapped),
              0xFFFFFFFF_u32, # INFINITE
            )

            # Stop sentinel: stop() posted a completion with null overlapped.
            break if overlapped.null?

            entry = @mu.synchronize { @by_overlapped[overlapped.address.to_u64]? }
            # Entry was removed (remove_watch / stop raced this completion).
            unless entry
              next
            end

            if ok == 0
              # Pending IO got cancelled — entry is being torn down. Skip.
              next
            end

            process_completion(entry, bytes.to_i32) if bytes > 0
            # Always re-arm: the kernel returns to "no IO pending" after each
            # completion, even on zero-byte (buffer-overflow) deliveries.
            arm_read(entry) if @mu.synchronize { @watches[entry.path]?.same?(entry) }
          end
        end

        private def process_completion(entry : Entry, bytes_total : Int32) : Nil
          on_event = @mu.synchronize { @on_event }
          return unless on_event

          offset = 0
          buf = entry.buffer
          while offset < bytes_total
            info_ptr = (buf + offset).as(LibKernel32FileWatch::FileNotifyInformation*)
            info = info_ptr.value

            # FileName starts immediately after the 12-byte fixed header.
            name_bytes = info.file_name_length.to_i32
            name_ptr = (buf + offset + sizeof(LibKernel32FileWatch::FileNotifyInformation)).as(UInt16*)
            filename = String.from_utf16(Slice.new(name_ptr, name_bytes // 2))

            if relevant?(entry, filename)
              kind = action_to_kind(info.action)
              on_event.call(entry.path, kind) if kind
            end

            break if info.next_entry_offset == 0
            offset += info.next_entry_offset.to_i32
          end
        end

        # When the user watched a file: only emit if the reported child name
        # matches that file's basename. When the user watched a directory:
        # everything inside counts.
        private def relevant?(entry : Entry, filename : String) : Bool
          if base = entry.file_basename
            filename == base
          else
            true
          end
        end

        private def action_to_kind(action : UInt32) : String?
          case action
          when LibKernel32FileWatch::FILE_ACTION_ADDED
            "created"
          when LibKernel32FileWatch::FILE_ACTION_REMOVED
            "deleted"
          when LibKernel32FileWatch::FILE_ACTION_MODIFIED
            "modified"
          when LibKernel32FileWatch::FILE_ACTION_RENAMED_OLD_NAME,
               LibKernel32FileWatch::FILE_ACTION_RENAMED_NEW_NAME
            "renamed"
          end
        end
      end
    end
  end
{% end %}
