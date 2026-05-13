module LuneCLI
  # Platform-specific npm executable name.
  {% if flag?(:win32) %}
    NPM_CMD = "npm.cmd"
  {% else %}
    NPM_CMD = "npm"
  {% end %}

  # Default toolchain commands (overridable via lune.yml).
  DEFAULT_INSTALL_CMD = "#{NPM_CMD} install"
  DEFAULT_DEV_CMD     = "#{NPM_CMD} run dev"
  DEFAULT_BUILD_CMD   = "#{NPM_CMD} run build"

  # Paths.
  DEV_BINARY = ".lune-dev"
  BUILD_DIR  = File.join("build", "bin")
end
