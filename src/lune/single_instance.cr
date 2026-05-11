module Lune
  module SingleInstance
    # Tries to acquire an exclusive non-blocking flock on the lock file.
    # Returns the open File (which must stay open to hold the lock) or nil
    # if another process already holds it.
    def self.acquire(app_slug : String, dir : String = File.join(Path.home, ".lune")) : File?
      Dir.mkdir_p(dir)
      lock_path = File.join(dir, "#{app_slug}.lock")

      lock_file = File.open(lock_path, "w")
      lock_file.flock_exclusive(blocking: false)
      lock_file.print(Process.pid)
      lock_file.flush
      lock_file
    rescue File::Error | IO::Error
      lock_file.try(&.close)
      nil
    end

    # Converts an app title into a safe filename slug.
    def self.slug(title : String) : String
      s = title.downcase.gsub(/[^a-z0-9]+/, "-").lstrip('-').rstrip('-')
      s.empty? ? "app" : s
    end
  end
end
