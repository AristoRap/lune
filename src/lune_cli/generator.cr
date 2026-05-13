module LuneCLI
  module Generator
    def self.generate_bindings(app_entry : String, frontend_dir : String)
      env = ENV.to_h.merge({Lune::ENV_FRONTEND_DIR => frontend_dir})
      crystal_args = ["run", app_entry, "-Dpreview_mt", "-Dbuild_mode"]

      app_status = Process.run(
        "crystal",
        crystal_args,
        env: env,
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )
      return false unless app_status.success?
    end
  end
end
