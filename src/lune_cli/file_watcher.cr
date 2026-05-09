module LuneCLI
  class FileWatcher
    getter poll_interval : Time::Span
    getter debounce : Time::Span

    def initialize(@poll_interval : Time::Span = 500.milliseconds, @debounce : Time::Span = 200.milliseconds)
    end

    def collect_mtimes(dir : String) : Hash(String, Time)
      mtimes = {} of String => Time
      Dir.glob(File.join(dir, "**", "*.cr")) do |path|
        mtimes[path] = File.info(path).modification_time
      end
      mtimes
    end

    def changed?(before : Hash(String, Time), after : Hash(String, Time)) : Bool
      before != after
    end

    # Blocks until a .cr file in src_dir changes or the process exits.
    # Returns true if a change was detected (caller should restart), false if
    # the process exited on its own.
    def watch(process : Process, src_dir : String) : Bool
      exited = Channel(Nil).new(1)
      spawn do
        process.wait
        exited.send(nil)
      end

      mtimes = collect_mtimes(src_dir)

      loop do
        select
        when exited.receive
          return false
        else
          sleep poll_interval
          new_mtimes = collect_mtimes(src_dir)
          if changed?(mtimes, new_mtimes)
            sleep debounce
            process.terminate(graceful: false)
            exited.receive
            return true
          end
          mtimes = new_mtimes
        end
      end
    end

    def wait_for_change(src_dir : String) : Nil
      mtimes = collect_mtimes(src_dir)
      loop do
        sleep poll_interval
        new_mtimes = collect_mtimes(src_dir)
        if changed?(mtimes, new_mtimes)
          sleep debounce
          return
        end
        mtimes = new_mtimes
      end
    end
  end
end
