module LuneCLI
  struct Context
    getter app_name : String
    getter frontend_dir : String
    getter skip_install : Bool
    getter template : String

    def initialize(
      @app_name : String,
      @frontend_dir : String = "frontend",
      @skip_install : Bool = false,
      @template : String = "vanilla",
    )
    end
  end
end
