import { defineConfig } from 'vitepress'

const version = '0.11.0'

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
          { text: 'Error Handling', link: '/guide/error-handling' },
          { text: 'Events', link: '/guide/events' },
          { text: 'Stream', link: '/guide/stream' },
          { text: 'TypeScript', link: '/guide/typescript' },
          { text: 'Window', link: '/guide/window' },
          { text: 'Menubar Apps', link: '/guide/menubar' },
          { text: 'Distribution', link: '/guide/distribution' },
          { text: 'Windows Verification Checklist', link: '/guide/windows-checklist' },
        ],
      },
      {
        text: 'Capabilities',
        items: [
          { text: 'Overview', link: '/capabilities/' },
          {
            text: 'Core',
            items: [
              { text: 'Events', link: '/capabilities/events' },
              { text: 'Stream', link: '/capabilities/stream' },
            ],
          },
          {
            text: 'Standard',
            items: [
              { text: 'Clipboard', link: '/capabilities/clipboard' },
              { text: 'Context Menu', link: '/capabilities/context-menu' },
              { text: 'Deep Link', link: '/capabilities/deep-link' },
              { text: 'Dialogs', link: '/capabilities/dialogs' },
              { text: 'Drag Out', link: '/capabilities/drag-out' },
              { text: 'File Drop', link: '/capabilities/file-drop' },
              { text: 'File Watch', link: '/capabilities/file-watch' },
              { text: 'Hotkeys', link: '/capabilities/hotkeys' },
              { text: 'Filesystem', link: '/capabilities/filesystem' },
              { text: 'Notifications', link: '/capabilities/notifications' },
              { text: 'Screen', link: '/capabilities/screen' },
              { text: 'KV', link: '/capabilities/kv' },
              { text: 'Shell', link: '/capabilities/shell' },
              { text: 'SQLite', link: '/capabilities/sqlite' },
              { text: 'System', link: '/capabilities/system' },
              { text: 'Tray', link: '/capabilities/tray' },
              { text: 'Window', link: '/capabilities/window' },
              { text: 'Windows', link: '/capabilities/windows' },
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
