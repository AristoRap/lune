require "./base"

module LuneCLI
  module Scaffolds
    ecr_resource SveltePackage, "package.json", "./templates/svelte/package.ecr"
    ecr_resource SvelteViteConfig, "vite.config.js", "./templates/svelte/vite.config.ecr"
    ecr_resource SvelteConfig, "svelte.config.js", "./templates/svelte/svelte.config.ecr"
    ecr_resource SvelteMain, "src/main.js", "./templates/svelte/main.ecr"
    ecr_resource SvelteApp, "src/App.svelte", "./templates/svelte/App.svelte.ecr"
    ecr_resource SvelteLogo, "src/assets/images/svelte.svg", "./templates/svelte/assets/images/svelte.svg.ecr"

    resource_group Svelte, HtmlIndex, SveltePackage, SvelteViteConfig, SvelteConfig, SvelteMain, SvelteApp, StyleCSS, LuneLogo, SvelteLogo
  end
end
