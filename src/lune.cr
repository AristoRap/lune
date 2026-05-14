require "./lune/asset_server"
require "./lune/assets"
require "./lune/config"
require "./lune/options"
require "./lune/logger"
require "./lune/binding_def"
require "./lune/bindings/*"
require "./lune/webview"
require "./lune/error"
require "./lune/bridge"
require "./lune/runtime"
require "./lune/installable"
require "./lune/bindable"
require "./lune/app"
require "./lune/single_instance"
require "./lune/runner"

module Lune
  VERSION = "0.3.6"

  # Default frontend directory name (matches the lune.yml default).
  DEFAULT_FRONTEND_DIR = "frontend"

  # Subdirectory under frontend.dir where Lune writes its generated JS/TS files.
  LUNEJS_SUBDIR = "lunejs"

  # Environment variables written by the CLI and read by the compiled app.
  ENV_DEV_URL      = "LUNE_DEV_URL"
  ENV_FRONTEND_DIR = "LUNE_FRONTEND_DIR"
  ENV_PREGEN       = "LUNE_PREGEN"

  # Navigation priority (first match wins):
  #   1. html:   — inline HTML string (useful for tests and simple apps)
  #   2. url:    — explicit URL
  #   3. LUNE_DEV_URL env var — Vite dev server (set automatically by the CLI)
  #   4. assets: — directory embedded at compile time, served locally in prod
  #

  macro run(app, **options, &block)
    {% if options[:assets] %}
      ::Lune::Assets.embed_dir({{ options[:assets] }})
    {% end %}

    {% if flag?(:build_mode) %}
      ::Lune.logger.info { "Running in build mode" }
      appl = {{ app }}
      lunejs_dir = File.join(ENV.fetch(Lune::ENV_FRONTEND_DIR, Lune::DEFAULT_FRONTEND_DIR), Lune::LUNEJS_SUBDIR)
      ::Lune::Runtime.write_js(appl.bindings, lunejs_dir)
    {% else %}
      runner = ::Lune::Runner.new({{ app }}) do |opts|
        {% if block %}
          {{ block.body }}
        {% end %}
      end
      runner.start
    {% end %}
  end
end
