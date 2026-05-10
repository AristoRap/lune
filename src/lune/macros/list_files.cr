dir = ARGV[0].chomp("/")
Dir.glob("#{dir}/**/*").sort.each do |path|
  next unless File.file?(path)
  puts "./" + path[(dir.size + 1)..]
end
