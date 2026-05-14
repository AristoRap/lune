import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Lune',
  description: 'Build desktop apps with Crystal',
  base: '/lune/',
  cleanUrls: true,
  themeConfig: {
    logo: '/logo.svg',
    nav: [
      { text: 'Guide', link: '/getting-started' },
      { text: 'CLI', link: '/cli-reference' },
      { text: 'GitHub', link: 'https://github.com/AristoRap/lune' },
    ],
    sidebar: [
      { text: 'Getting Started', link: '/getting-started' },
      {
        text: 'Guide',
        items: [
          { text: 'How It Works', link: '/guide/how-it-works' },
          { text: 'Assets & Build', link: '/guide/assets' },
          { text: 'Bindings', link: '/guide/bindings' },
          { text: 'Error Handling', link: '/guide/error-handling' },
          { text: 'Events', link: '/guide/events' },
          { text: 'TypeScript', link: '/guide/typescript' },
          { text: 'Window', link: '/guide/window' },
        ],
      },
      { text: 'CLI Reference', link: '/cli-reference' },
      { text: 'Configuration', link: '/configuration' },
    ],
    search: {
      provider: 'local',
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/AristoRap/lune' },
    ],
    footer: {
      message: 'Released under the MIT License.',
    },
  },
})
