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
        escaped = error_text
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")

        <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body { background: #130a0a; color: #fca5a5; font: 13px/1.6 ui-monospace, "Cascadia Code", monospace; }
            header { padding: 14px 20px; background: #1f0f0f; border-bottom: 1px solid #3b1515; color: #f87171; font-weight: 600; letter-spacing: .02em; }
            pre { padding: 18px 20px; white-space: pre-wrap; word-break: break-all; color: #fecaca; }
          </style>
        </head>
        <body>
          <header>Crystal compilation error</header>
          <pre>#{escaped}</pre>
        </body>
        </html>
        HTML
      end
    end
  end
end
