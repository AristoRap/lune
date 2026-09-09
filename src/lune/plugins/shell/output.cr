require "deque"

module Lune
  module Plugins
    class Shell < Lune::Plugin
      struct OutputRecord
        include JSON::Serializable
        getter seq : Int64
        getter stream : String
        getter line : String
        getter truncated : Bool

        def initialize(@seq, @stream, @line, @truncated)
        end
      end

      struct Snapshot
        include JSON::Serializable
        getter pid : String
        getter cursor : Int64
        getter gap : Bool
        getter running : Bool
        @[JSON::Field(emit_null: true)]
        getter code : Int32?
        getter records : Array(OutputRecord)
        getter errors : Array(String)

        def initialize(@pid, @cursor, @gap, @running, @code, @records, @errors)
        end
      end

      # Accessed only while Shell's mutex is held. Status is separate from the
      # output ring, so output eviction cannot discard completion.
      class OutputHistory
        getter cursor = 0_i64
        property running = true
        property code : Int32? = nil
        getter errors = [] of String
        @records = Deque(OutputRecord).new
        @bytes = 0_i64

        def initialize(@max_records : Int32, @max_bytes : Int32)
        end

        def append(stream : String, line : String, truncated : Bool) : Nil
          @cursor += 1
          @records << OutputRecord.new(@cursor, stream, line, truncated)
          @bytes += line.bytesize
          while @records.size > @max_records || @bytes > @max_bytes
            @bytes -= @records.shift.line.bytesize
          end
        end

        def snapshot(pid : String, after : Int64) : Snapshot
          if after < 0 || after > @cursor
            raise Lune::Error.new("shell_invalid_cursor", "Cursor must be between 0 and #{@cursor} for process #{pid}")
          end
          first = @records.first?.try(&.seq) || (@cursor + 1)
          Snapshot.new(pid, @cursor, after < first - 1, @running, @code,
            @records.select { |record| record.seq > after }.to_a, @errors.dup)
        end
      end

      # Keep a bounded prefix of each line and drain any excess. Accumulating
      # bytes before decoding preserves multibyte text across read boundaries.
      # Invalid UTF-8 (including an incomplete character at the truncation
      # boundary) is replaced with U+FFFD before it reaches JSON/JavaScript.
      module OutputReader
        def self.each_line(io : IO, max_bytes : Int32, & : String, Bool ->) : Nil
          buffer = Bytes.new(8192)
          line = IO::Memory.new
          truncated = false
          while (count = io.read(buffer)) > 0
            start = 0
            count.times do |index|
              next unless buffer[index] == '\n'.ord
              part = buffer[start, index - start]
              keep = Math.min(part.size, max_bytes - line.size)
              line.write(part[0, keep])
              truncated ||= keep < part.size
              text = line.to_s
              text = text.chomp unless truncated
              yield text.scrub, truncated
              line.clear
              truncated = false
              start = index + 1
            end
            part = buffer[start, count - start]
            keep = Math.min(part.size, max_bytes - line.size)
            line.write(part[0, keep])
            truncated ||= keep < part.size
          end
          unless line.empty? && !truncated
            text = line.to_s
            text = text.chomp unless truncated
            yield text.scrub, truncated
          end
        end
      end
    end
  end
end
