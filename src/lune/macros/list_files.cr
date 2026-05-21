dir = ARGV[0].chomp("/")
# Dir.glob on Windows returns paths with `\` separators even when the
# pattern uses `/`, so we'd otherwise emit routes like `/nested\info.txt`
# and any nested asset would be unreachable via its `/nested/...` URL.
# Normalize both the prefix and the matched paths to posix.
posix_dir = Path[dir].to_posix.to_s
Dir.glob("#{posix_dir}/**/*").sort.each do |path|
  next unless File.file?(path)
  posix = Path[path].to_posix.to_s
  puts "./" + posix[(posix_dir.size + 1)..]
end
