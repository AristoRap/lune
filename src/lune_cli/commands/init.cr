require "yaml"
require "../scaffolds/shared"
require "../scaffolds/vanilla"
require "../scaffolds/vue"

module LuneCLI
  class InitCommand
    def to_command : Argy::Command
      command = Argy::Command.new(
        use: "init [APP_NAME]",
        short: "Initialize a new Lune app",
        long: "Initialize a new Lune app in the current directory."
      )
      command.flags.bool("skip-install", 's', false, "Skip running shards install and npm install")
      command.flags.string("template", 't', "vanilla", "Template to use [vanilla|vue]")

      command.on_pre_run do |cmd, args|
        unless args.first?
          raise Argy::Error.new("Missing app name. Usage: lune init [APP_NAME]")
        end
      end

      command.on_run do |cmd, args|
        app_name = sanitize_app_name(args.first)
        skip_install = cmd.bool_flag("skip-install")
        template = cmd.string_flag("template")
        ctx = Context.new(app_name, skip_install: skip_install, template: template)

        Lune.logger.info { "Initializing new Lune app '#{app_name}'..." }

        if run(ctx)
          Lune.logger.info { "Done! To get started:" }
          Lune.logger.info { "  cd #{app_name}" }
          Lune.logger.info { "  lune dev" }
        else
          raise Argy::Error.new("Init failed")
        end
      end

      command
    end

    def run(ctx : Context) : Bool
      check_crystal!
      check_node!

      scaffold_crystal(ctx.app_name)
      inject_dependency(File.join(ctx.app_name, "shard.yml"))
      scaffold_shared(ctx)
      scaffold_frontend(ctx)

      unless ctx.skip_install
        run_shards_install(ctx.app_name)
        run_npm_install(ctx.app_name, ctx.frontend_dir)
      end

      gitignore_path = File.join(ctx.app_name, ".gitignore")
      File.write(
        gitignore_path,
        File.read(gitignore_path) + "\n#{ctx.frontend_dir}/dist/\n#{ctx.frontend_dir}/lunejs/\nnode_modules/\nbuild/bin/\n.lune-dev\n.lune-dev.dwarf\n"
      )

      true
    end

    private def check_crystal!
      status = Process.run(
        "crystal", ["--version"],
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )
      raise Argy::Error.new("crystal not found — install it from https://crystal-lang.org") unless status.success?
    end

    private def check_node!
      status = Process.run(
        "node", ["--version"],
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )
      raise Argy::Error.new("node not found — install it from https://nodejs.org") unless status.success?
    end

    private def scaffold_crystal(app_name : String)
      Lune.logger.debug { "Running crystal init app #{app_name}" }
      status = Process.run(
        "crystal", ["init", "app", app_name],
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )
      raise Argy::Error.new("crystal init failed") unless status.success?
    end

    def inject_dependency(shard_yml_path : String)
      Lune.logger.debug { "Injecting lune dependency into shard.yml" }

      raw = YAML.parse(File.read(shard_yml_path)).as_h
      deps = raw[YAML::Any.new("dependencies")]?
        .try(&.as_h.dup) || {} of YAML::Any => YAML::Any

      lune_dep = {} of YAML::Any => YAML::Any

      lune_dep[YAML::Any.new("github")] = YAML::Any.new("aristorap/lune")
      lune_dep[YAML::Any.new("version")] = YAML::Any.new("~> #{Lune::VERSION.split(".").first(2).join(".")}")

      deps[YAML::Any.new("lune")] = YAML::Any.new(lune_dep)
      raw[YAML::Any.new("dependencies")] = YAML::Any.new(deps)

      File.write(shard_yml_path, raw.to_yaml)
    end

    private def scaffold_shared(ctx : Context)
      Lune.logger.debug { "Scaffolding shared Crystal entry files..." }
      LuneCLI::Scaffolds::Shared.new(ctx).resources.each do |resource|
        resource_path = File.join(ctx.app_name, resource[:file])
        FileUtils.mkdir_p(File.dirname(resource_path))
        write_resource(resource_path, resource[:rendered])
      end
    end

    private def scaffold_frontend(ctx : Context)
      Lune.logger.debug { "Scaffolding #{ctx.template} frontend in #{ctx.frontend_dir}/" }

      frontend_dir = File.join(ctx.app_name, ctx.frontend_dir)

      template_scaffolds = case ctx.template
                           when "vanilla" then LuneCLI::Scaffolds::Vanilla.new(ctx)
                           when "vue"     then LuneCLI::Scaffolds::Vue.new(ctx)
                           else
                             raise Argy::Error.new("Unknown template: #{ctx.template}")
                           end

      template_scaffolds.resources.each do |resource|
        resource_path = File.join(frontend_dir, resource[:file])
        FileUtils.mkdir_p(File.dirname(resource_path))
        write_resource(resource_path, resource[:rendered])
      end

      FileUtils.mkdir_p(File.join(frontend_dir, "dist"))
    end

    def shards_install_args : Array(String)
      args = ["install"]
      {% if flag?(:win32) %}
        args << "--skip-postinstall"
      {% end %}
      args
    end

    private def run_shards_install(app_name : String)
      Lune.logger.info { "Running shards install..." }
      status = Process.run(
        "shards", shards_install_args,
        chdir: app_name,
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )
      raise Argy::Error.new("shards install failed") unless status.success?
    end

    private def run_npm_install(app_name : String, frontend_dir : String)
      Lune.logger.info { "Running npm install..." }
      status = Process.run(
        NPM_CMD, ["install"],
        chdir: File.join(app_name, frontend_dir),
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )
      raise Argy::Error.new("npm install failed") unless status.success?
    end

    private def write_resource(path : String, content : String) : Nil
      if File.exists?(path)
        Lune.logger.info { "File #{path} already exists, skipping" }
      else
        File.write(path, content)
      end
    end

    private def sanitize_app_name(name : String) : String
      name.strip.downcase.gsub(/[\s\/\\]/, "_")
    end
  end
end
