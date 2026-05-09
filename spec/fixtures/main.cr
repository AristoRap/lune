require "../../src/lune"

# Frontend probe with Vite.
# Prod mode:
#   cd frontend && npm run build
#   crystal run main.cr -Dpreview_mt
#
# Run with: crystal run main.cr -Dpreview_mt

Lune::Assets.embed_dir({{ "frontend/dist" }})

Lune.run(
  title: "asset embed test",
  width: 1200,
  height: 800,
  debug: true
) do |app|
  app.bind_typed("ping", String) do |msg|
    puts "ping(#{msg})"
    JSON::Any.new("pong from Crystal: #{msg}")
  end
end
