module Lune
  module SingleInstance
    # Tries to acquire an exclusive non-blocking flock on the lock file.
    # Returns the open File (which must stay open to hold the lock) or nil
    # if another process already holds it.
    def self.acquire(app_slug : String, dir : String = File.join(Path.home, ".lune")) : File?
      Dir.mkdir_p(dir)
      lock_path = File.join(dir, "#{app_slug}.lock")

      lock_file = File.open(lock_path, "w")
      result = LibC.flock(lock_file.fd, LibC::FlockOp::EX | LibC::FlockOp::NB)
      unless result == 0
        lock_file.close
        return nil
      end

      lock_file.print(Process.pid)
      lock_file.flush
      lock_file
    rescue ex : File::Error
      Lune.logger.error { "Single-instance: could not open lock file: #{ex.message}" }
      nil
    end

    # Converts an app title into a safe filename slug.
    def self.slug(title : String) : String
      s = title.downcase.gsub(/[^a-z0-9]+/, "-").lstrip('-').rstrip('-')
      s.empty? ? "app" : s
    end
  end
end
