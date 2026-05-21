module LuneCLI
  # On Windows, Crystal's `Process.run` / `Process.new` bypasses cmd.exe
  # and only resolves `.exe` binaries directly. npm.cmd / yarn.cmd /
  # pnpm.cmd shims all fail with `File::NotFoundError`, and a user-
  # configured `frontend.build: "npm run build"` in lune.yml fails the
  # same way (the bare token `npm` requires PATHEXT to be honoured,
  # which only cmd.exe does). Wrapping every external-tool launch in
  # `cmd /c` lets cmd.exe do shim resolution + PATHEXT search the way
  # users expect from a regular shell. POSIX path is unchanged.
  module ProcessSpawn
    def self.wrap(cmd : String, args : Array(String)) : Tuple(String, Array(String))
      {% if flag?(:win32) %}
        {"cmd", ["/c", cmd] + args}
      {% else %}
        {cmd, args}
      {% end %}
    end
  end
end
