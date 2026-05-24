import { defineConfig } from 'vitepress'

const version = '0.14.1'

export default defineConfig({
  title: 'Lune',
  description: 'Build desktop apps with Crystal',
  base: '/lune/',
  cleanUrls: true,
  themeConfig: {
    logo: '/lune.svg',
    nav: [
      { text: `v${version}`, link: 'https://github.com/AristoRap/lune/releases' },
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
          { text: 'Authoring Plugins', link: '/guide/authoring-plugins' },
          { text: 'Error Handling', link: '/guide/error-handling' },
          { text: 'Event', link: '/guide/event' },
          { text: 'Stream', link: '/guide/stream' },
          { text: 'TypeScript', link: '/guide/typescript' },
          { text: 'Window', link: '/guide/window' },
          { text: 'Menubar Apps', link: '/guide/menubar' },
          { text: 'Distribution', link: '/guide/distribution' },
        ],
      },
      {
        text: 'Plugins',
        items: [
          { text: 'Overview', link: '/plugins/' },
          {
            text: 'Core',
            items: [
              { text: 'Event', link: '/plugins/event' },
              { text: 'Stream', link: '/plugins/stream' },
            ],
          },
          {
            text: 'Standard',
            items: [
              { text: 'Clipboard', link: '/plugins/clipboard' },
              { text: 'Context Menu', link: '/plugins/context-menu' },
              { text: 'Deep Link', link: '/plugins/deep-link' },
              { text: 'Dialogs', link: '/plugins/dialogs' },
              { text: 'Drag Out', link: '/plugins/drag-out' },
              { text: 'Edit Shortcuts', link: '/plugins/edit-shortcuts' },
              { text: 'File Drop', link: '/plugins/file-drop' },
              { text: 'File Watch', link: '/plugins/file-watch' },
              { text: 'Hotkeys', link: '/plugins/hotkeys' },
              { text: 'Filesystem', link: '/plugins/filesystem' },
              { text: 'Navigation', link: '/plugins/navigation' },
              { text: 'KV', link: '/plugins/kv' },
              { text: 'Shell', link: '/plugins/shell' },
              { text: 'SQLite', link: '/plugins/sqlite' },
              { text: 'System', link: '/plugins/system' },
              { text: 'Tray', link: '/plugins/tray' },
              { text: 'Window', link: '/plugins/window' },
              { text: 'Windows', link: '/plugins/windows' },
            ],
          },
        ],
      },
      { text: 'CLI Reference', link: '/cli-reference' },
      { text: 'Configuration', link: '/configuration' },
    ],
    search: {
      provider: 'local',
    },

    outline: [2, 4],
    footer: {
      message: 'Released under the MIT License.',
    },
  },
})
