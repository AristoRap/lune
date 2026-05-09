require "./base"

module LuneCLI
  module Scaffolds
    ecr_resource VanillaPackage, "package.json", "./templates/vanilla/package.ecr"
    ecr_resource VanillaViteConfig, "vite.config.js", "./templates/vanilla/vite.config.ecr"
    ecr_resource VanillaJS, "src/main.js", "./templates/vanilla/js.ecr"

    resource_group Vanilla, HtmlIndex, VanillaPackage, VanillaViteConfig, VanillaJS, StyleCSS, LuneLogo, ViteLogo
  end
end
