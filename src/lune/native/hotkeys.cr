module Lune
  module Native
    {% if flag?(:lune_native_test_mock) %}
      module HotkeysMock
        @@registered = [] of String
        @@handler : (String -> Nil)? = nil

        def self.reset
          @@registered.clear
          @@handler = nil
        end

        def self.registered
          @@registered
        end

        def self.set_handler(cb : String -> Nil)
          @@handler = cb
        end

        def self.simulate(accelerator : String)
          @@handler.try(&.call(accelerator))
        end
      end
    {% elsif flag?(:darwin) %}
      {% system("cd '#{__DIR__}/../../../ext/native/macos' && clang -c hotkeys.m -o hotkeys.o -fobjc-arc -Wno-deprecated-declarations 2>/dev/null") %}

      @[Link(framework: "Carbon")]
      @[Link(framework: "AppKit")]
      @[Link(ldflags: "#{__DIR__}/../../../ext/native/macos/hotkeys.o")]
      lib LibNativeHotkeys
        fun lune_hotkeys_init(
          cb  : (LibC::Char*, Void*) ->,
          ctx : Void*
        ) : Void
        fun lune_hotkeys_register(accelerator : LibC::Char*) : LibC::Int
        fun lune_hotkeys_unregister(accelerator : LibC::Char*) : LibC::Int
        fun lune_hotkeys_unregister_all : Void
      end
    {% elsif flag?(:linux) %}
      @[Link("X11")]
      lib LibX11Hotkeys
        alias XDisplay = Void*
        alias XWindow  = LibC::ULong

        struct XEvent
          type : LibC::Int
          pad  : StaticArray(LibC::Long, 23)
        end

        struct XKeyEvent
          type       : LibC::Int
          serial     : LibC::ULong
          send_event : LibC::Int
          display    : XDisplay
          window     : XWindow
          root       : XWindow
          subwindow  : XWindow
          time       : LibC::ULong
          x          : LibC::Int
          y          : LibC::Int
          x_root     : LibC::Int
          y_root     : LibC::Int
          state      : LibC::UInt
          keycode    : LibC::UInt
          same_screen: LibC::Int
        end

        KeyPress      =  2_i32
        GrabModeAsync =  1_i32
        ControlMask   =  4_u32
        ShiftMask     =  1_u32
        Mod1Mask      =  8_u32
        Mod4Mask      = 64_u32

        fun XOpenDisplay(name : LibC::Char*) : XDisplay
        fun XDefaultRootWindow(dpy : XDisplay) : XWindow
        fun XNextEvent(dpy : XDisplay, event : XEvent*) : LibC::Int
        fun XPending(dpy : XDisplay) : LibC::Int
        fun XGrabKey(dpy : XDisplay, keycode : LibC::Int, modifiers : LibC::UInt,
                     grab_window : XWindow, owner_events : LibC::Int,
                     pointer_mode : LibC::Int, keyboard_mode : LibC::Int) : LibC::Int
        fun XUngrabKey(dpy : XDisplay, keycode : LibC::Int, modifiers : LibC::UInt,
                       grab_window : XWindow) : LibC::Int
        fun XKeysymToKeycode(dpy : XDisplay, keysym : LibC::ULong) : LibC::UInt
        fun XStringToKeysym(str : LibC::Char*) : LibC::ULong
        fun XFlush(dpy : XDisplay) : LibC::Int
      end
    {% end %}

    module Hotkeys
      @@box     : Void*? = nil
      @@started : Bool   = false

      {% if flag?(:lune_native_test_mock) %}
        def self.init(&handler : String -> Nil)
          HotkeysMock.set_handler(handler)
        end

        def self.register(accelerator : String) : Bool
          HotkeysMock.registered << accelerator unless HotkeysMock.registered.includes?(accelerator)
          true
        end

        def self.unregister(accelerator : String) : Bool
          found = HotkeysMock.registered.includes?(accelerator)
          HotkeysMock.registered.delete(accelerator)
          found
        end

        def self.unregister_all : Nil
          HotkeysMock.registered.clear
        end

      {% elsif flag?(:darwin) %}
        def self.init(&handler : String -> Nil)
          cb = handler
          @@box = Box.box(cb)
          LibNativeHotkeys.lune_hotkeys_init(
            ->(key : LibC::Char*, ctx : Void*) {
              fn = Box(Proc(String, Nil)).unbox(ctx)
              fn.call(String.new(key))
            },
            @@box.not_nil!
          )
          @@started = true
        end

        def self.register(accelerator : String) : Bool
          return false unless @@started
          LibNativeHotkeys.lune_hotkeys_register(accelerator) != 0
        end

        def self.unregister(accelerator : String) : Bool
          return false unless @@started
          LibNativeHotkeys.lune_hotkeys_unregister(accelerator) != 0
        end

        def self.unregister_all : Nil
          LibNativeHotkeys.lune_hotkeys_unregister_all if @@started
          @@started = false
        end

      {% elsif flag?(:linux) %}
        @@dpy     : LibX11Hotkeys::XDisplay = Pointer(Void).null
        @@mu      = Mutex.new
        @@hotkeys = {} of String => {LibC::Int, LibC::UInt}
        @@handler : (String -> Nil)? = nil

        private def self.normalize_key(name : String) : String
          case name.downcase
          when "space"              then "space"
          when "return", "enter"    then "Return"
          when "tab"                then "Tab"
          when "backspace", "back"  then "BackSpace"
          when "delete", "del"      then "Delete"
          when "escape", "esc"      then "Escape"
          when "left"               then "Left"
          when "right"              then "Right"
          when "up"                 then "Up"
          when "down"               then "Down"
          when "home"               then "Home"
          when "end"                then "End"
          when "pageup", "pgup"     then "Page_Up"
          when "pagedown", "pgdn"   then "Page_Down"
          when "insert"             then "Insert"
          when /^f(\d+)$/           then "F#{$~[1]}"
          else                           name.downcase
          end
        end

        private def self.parse_acc(dpy, accelerator : String) : {LibC::Int, LibC::UInt}?
          mods = 0_u32
          key_name = ""
          accelerator.split("+").each do |part|
            case part.downcase
            when "ctrl", "control"          then mods |= LibX11Hotkeys::ControlMask
            when "shift"                    then mods |= LibX11Hotkeys::ShiftMask
            when "alt"                      then mods |= LibX11Hotkeys::Mod1Mask
            when "super", "cmd", "command"  then mods |= LibX11Hotkeys::Mod4Mask
            else key_name = part
            end
          end
          return nil if key_name.empty?
          norm = normalize_key(key_name)
          sym  = LibX11Hotkeys.XStringToKeysym(norm)
          sym  = LibX11Hotkeys.XStringToKeysym(key_name) if sym == 0
          return nil if sym == 0
          code = LibX11Hotkeys.XKeysymToKeycode(dpy, sym.to_u64)
          return nil if code == 0
          {code.to_i32, mods}
        end

        def self.init(&handler : String -> Nil)
          dpy = LibX11Hotkeys.XOpenDisplay(Pointer(LibC::Char).null)
          return if dpy.null?
          @@dpy     = dpy
          @@handler = handler
          @@started = true

          Fiber::ExecutionContext::Isolated.new("lune-hotkeys") do
            event = LibX11Hotkeys::XEvent.new
            while @@started
              pending = LibX11Hotkeys.XPending(dpy)
              if pending <= 0
                sleep 10.milliseconds
                next
              end
              LibX11Hotkeys.XNextEvent(dpy, pointerof(event))
              next unless event.type == LibX11Hotkeys::KeyPress
              ke    = pointerof(event).as(LibX11Hotkeys::XKeyEvent*).value
              state = ke.state & ~0x2000_u32  # strip Mod2 (NumLock)
              cb    = @@handler
              @@mu.synchronize do
                @@hotkeys.each do |acc, (code, mods)|
                  cb.try(&.call(acc)) if ke.keycode == code.to_u32 && state == mods
                end
              end
            end
          end
        end

        def self.register(accelerator : String) : Bool
          return false unless @@started && !@@dpy.null?
          parsed = parse_acc(@@dpy, accelerator)
          return false unless parsed
          code, mods = parsed
          root = LibX11Hotkeys.XDefaultRootWindow(@@dpy)
          @@mu.synchronize do
            return true if @@hotkeys.has_key?(accelerator)
            LibX11Hotkeys.XGrabKey(@@dpy, code, mods, root, 0,
              LibX11Hotkeys::GrabModeAsync, LibX11Hotkeys::GrabModeAsync)
            @@hotkeys[accelerator] = {code, mods}
          end
          LibX11Hotkeys.XFlush(@@dpy)
          true
        end

        def self.unregister(accelerator : String) : Bool
          return false unless @@started && !@@dpy.null?
          entry = @@mu.synchronize { @@hotkeys.delete(accelerator) }
          return false unless entry
          code, mods = entry
          root = LibX11Hotkeys.XDefaultRootWindow(@@dpy)
          LibX11Hotkeys.XUngrabKey(@@dpy, code, mods, root)
          LibX11Hotkeys.XFlush(@@dpy)
          true
        end

        def self.unregister_all : Nil
          return unless @@started && !@@dpy.null?
          root    = LibX11Hotkeys.XDefaultRootWindow(@@dpy)
          entries = @@mu.synchronize { h = @@hotkeys.dup; @@hotkeys.clear; h }
          entries.each { |_, (code, mods)| LibX11Hotkeys.XUngrabKey(@@dpy, code, mods, root) }
          LibX11Hotkeys.XFlush(@@dpy)
          @@started = false
        end

      {% elsif flag?(:win32) %}
        def self.init(&handler : String -> Nil)
          raise NotImplementedError.new("Lune::Native::Hotkeys is not implemented on Windows yet (v0.10.0 backlog — will use RegisterHotKey + WM_HOTKEY). Exclude the `hotkeys` capability in lune.yml to silence this.")
        end

        def self.register(accelerator : String) : Bool
          raise NotImplementedError.new("Lune::Native::Hotkeys.register is not implemented on Windows yet (v0.10.0 backlog)")
        end

        def self.unregister(accelerator : String) : Bool
          raise NotImplementedError.new("Lune::Native::Hotkeys.unregister is not implemented on Windows yet (v0.10.0 backlog)")
        end

        def self.unregister_all : Nil
        end
      {% else %}
        def self.init(&handler : String -> Nil); end
        def self.register(accelerator : String) : Bool; false; end
        def self.unregister(accelerator : String) : Bool; false; end
        def self.unregister_all : Nil; end
      {% end %}
    end
  end
end
