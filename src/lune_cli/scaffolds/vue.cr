require "./base"

module LuneCLI
  module Scaffolds
    ecr_resource VuePackage, "package.json", "./templates/vue/package.ecr"
    ecr_resource VueViteConfig, "vite.config.js", "./templates/vue/vite.config.ecr"
    ecr_resource VueMain, "src/main.js", "./templates/vue/main.ecr"
    ecr_resource VueApp, "src/App.vue", "./templates/vue/App.vue.ecr"
    ecr_resource VueLogo, "src/assets/images/vue.svg", "./templates/vue/assets/images/vue.svg.ecr"

    resource_group Vue, HtmlIndex, VuePackage, VueViteConfig, VueMain, VueApp, StyleCSS, LuneLogo, VueLogo
  end
end
