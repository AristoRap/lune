module Lune
  # One-way Crystal→JS streaming bus. Used by capabilities (Shell, FileWatch,
  # SQLite, …) to push high-volume payloads that don't need an `emit`-style
  # round-trip. `#sender` is set by the Stream capability at install time.
  class Stream
    include Subscribable

    property sender : Proc(String, String, Nil)?

    def initialize
      @sender = nil
    end

    def send(name : String, data = nil)
      return unless (s = @sender)
      json = data.nil? ? "null" : data.to_json
      s.call(name, json)
    end
  end
end
