module LuneCLI
  module Commands
    class DevError
      def to_command : Argy::Command
        command = Argy::Command.new(use: "_dev-error", short: "", hidden: true)

        command.on_run do |_, _|
          error_text = STDIN.gets_to_end
          app = Lune::App.new
          Lune::Runner.new(app) do |opts|
            opts.title = "Crystal Error"
            opts.width = 880
            opts.height = 560
          end.start(html: build_html(error_text))
        end

        command
      end

      def build_html(error_text : String) : String
        escaped = HTML.escape(error_text)

        <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">

          <style>
            :root {
              --bg: #0f0f12;
              --panel: #16161c;
              --border: #2a2a35;
              --text: #e5e7eb;
              --muted: #9ca3af;
              --error: #f87171;
            }

            * {
              box-sizing: border-box;
            }

            body {
              margin: 0;
              background: var(--bg);
              color: var(--text);
              font: 13px/1.55 ui-monospace, SFMono-Regular,
                    Menlo, Consolas, monospace;
            }

            header {
              padding: 12px 16px;
              border-bottom: 1px solid var(--border);
              background: var(--panel);
              color: var(--error);
              font-weight: 600;
            }

            pre {
              margin: 0;
              padding: 16px;
              white-space: pre-wrap;
              overflow-wrap: anywhere;
              tab-size: 2;
            }
          </style>
        </head>

        <body>
          <header>Compilation failed</header>
          <pre><code>#{escaped}</code></pre>
        </body>
        </html>
        HTML
      end
    end
  end
end
