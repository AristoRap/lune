require "lune"

class Demo
  include Lune::Bindable

  @[Lune::Bind]
  def greet(name : String) : String
    n = name.strip.empty? ? "stranger" : name.strip
    "Hello, #{n}!"
  end

  @[Lune::Bind]
  def reverse(text : String) : String
    text.reverse
  end

  @[Lune::Bind]
  def file_info(path : String) : String
    return %({"error":"File not found"}) unless File.exists?(path)
    info = File.info(path)
    %({"size":#{info.size},"modified":"#{info.modification_time.to_rfc3339}"})
  rescue e
    %({"error":"#{e.message}"})
  end

  @[Lune::Bind]
  def fail_with(code : String) : String
    raise Lune::Error.new(code, "Demo error raised from Crystal (code: #{code})") unless code.empty?
    "ok"
  end

  @[Lune::Bind(async: true)]
  def process_files(paths : Array(String)) : Nil
    paths.each_with_index do |path, i|
      sleep 0.4.seconds
      @app.emit("fileProgress", {
        "done"  => i + 1,
        "total" => paths.size,
        "name"  => File.basename(path),
      })
    end
  end
end
