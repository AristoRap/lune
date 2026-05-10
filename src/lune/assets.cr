module Lune
  module Assets
    MIME_TYPES = {
      ".html"  => "text/html; charset=utf-8",
      ".js"    => "application/javascript",
      ".mjs"   => "application/javascript",
      ".css"   => "text/css",
      ".json"  => "application/json",
      ".png"   => "image/png",
      ".jpg"   => "image/jpeg",
      ".jpeg"  => "image/jpeg",
      ".gif"   => "image/gif",
      ".svg"   => "image/svg+xml",
      ".ico"   => "image/x-icon",
      ".woff"  => "font/woff",
      ".woff2" => "font/woff2",
      ".ttf"   => "font/ttf",
      ".eot"   => "application/vnd.ms-fontobject",
      ".webp"  => "image/webp",
      ".map"   => "application/json",
    }

    @@files = {} of String => Bytes

    # Embeds all files under `dir` at compile time into the binary.
    # Call this at the top level of your app file, not inside a method.
    # The path is relative to the file where the macro is called.
    #
    #   Lune::Assets.embed_dir("frontend/dist")
    #
    # Files are registered as "/<relative-path>" e.g. "/index.html", "/assets/main.js".
    macro embed_dir(dir)
      {% normalized_dir = dir.id.gsub(/"/, "") %}
      {% file_list = run("./macros/list_files", normalized_dir).strip.split('\n') %}
      {% for relative_path in file_list %}
        {% if relative_path != "" %}
          {% asset_path = normalized_dir + "/" + relative_path[2..] %}
          {% route = "/" + relative_path[2..] %}
          ::Lune::Assets.register({{ route }}, {{ read_file(asset_path) }}.to_slice)
        {% end %}
      {% end %}
    end

    def self.register(path : String, content : Bytes)
      @@files[path] = content
    end

    def self.get(path : String) : Bytes?
      @@files[path]?
    end

    def self.empty? : Bool
      @@files.empty?
    end

    def self.mime_for(path : String) : String
      MIME_TYPES[File.extname(path).downcase]? || "application/octet-stream"
    end
  end
end
