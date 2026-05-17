module Lune
  class Options
    class Menu
      # Parses human-readable shortcut strings (e.g. "cmd+n", "cmd+shift+z")
      # into a key character and NSEventModifierFlags bitmask for use in NSMenuItem.
      module Shortcut
        CMD   = 1_u64 << 20  # NSEventModifierFlagCommand
        SHIFT = 1_u64 << 17  # NSEventModifierFlagShift
        CTRL  = 1_u64 << 18  # NSEventModifierFlagControl
        OPT   = 1_u64 << 19  # NSEventModifierFlagOption

        # macOS key-equivalent strings for named keys (NSFunctionKeyMask characters
        # and standard control characters expected by setKeyEquivalent:).
        NAMED_KEYS = {
          "return"     => "\r",
          "enter"      => "\r",
          "tab"        => "\t",
          "escape"     => "\e",
          "esc"        => "\e",
          "delete"     => "\u{7f}",
          "backspace"  => "\u{7f}",
          "space"      => " ",
          "up"         => "\u{F700}",
          "down"       => "\u{F701}",
          "left"       => "\u{F702}",
          "right"      => "\u{F703}",
          "home"       => "\u{F729}",
          "end"        => "\u{F72B}",
          "pageup"     => "\u{F72C}",
          "page up"    => "\u{F72C}",
          "pagedown"   => "\u{F72D}",
          "page down"  => "\u{F72D}",
          "f1"         => "\u{F704}",
          "f2"         => "\u{F705}",
          "f3"         => "\u{F706}",
          "f4"         => "\u{F707}",
          "f5"         => "\u{F708}",
          "f6"         => "\u{F709}",
          "f7"         => "\u{F70A}",
          "f8"         => "\u{F70B}",
          "f9"         => "\u{F70C}",
          "f10"        => "\u{F70D}",
          "f11"        => "\u{F70E}",
          "f12"        => "\u{F70F}",
        }

        record Parsed, key : String, modifiers : UInt64

        def self.parse(shortcut : String) : Parsed
          tokens = shortcut.downcase.split("+")
          raise ArgumentError.new("Empty shortcut") if tokens.empty?

          key_token = tokens.last
          mod_tokens = tokens[0..-2]

          modifiers = 0_u64
          mod_tokens.each do |t|
            case t
            when "cmd", "command"       then modifiers |= CMD
            when "shift"                then modifiers |= SHIFT
            when "ctrl", "control"      then modifiers |= CTRL
            when "opt", "alt", "option" then modifiers |= OPT
            end
          end

          key = NAMED_KEYS[key_token]? || key_token
          # Single-letter keys require uppercase when shift is active — macOS convention.
          key = key.upcase if (modifiers & SHIFT) != 0 && key.size == 1

          Parsed.new(key: key, modifiers: modifiers)
        end
      end
    end
  end
end
