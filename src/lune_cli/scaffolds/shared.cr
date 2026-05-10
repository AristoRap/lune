require "./base"

module LuneCLI
  module Scaffolds
    ecr_resource CrystalMain, "src/main.cr", "./templates/shared/main.ecr"
    ecr_resource LuneConfig, "lune.yml", "./templates/shared/lune_config.ecr"

    resource_group Shared, CrystalMain, LuneConfig

    # Shared frontend resources — used by all Vite-based templates
    ecr_resource HtmlIndex, "index.html", "./templates/shared/index.ecr"
    ecr_resource StyleCSS, "src/style.css", "./templates/shared/css.ecr"
    ecr_resource LuneLogo, "src/assets/images/lune.svg", "./templates/shared/assets/images/lune.svg.ecr"
    ecr_resource ViteLogo, "src/assets/images/vite.svg", "./templates/shared/assets/images/vite.svg.ecr"
  end
end
