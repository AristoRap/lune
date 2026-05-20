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
    {% elsif flag?(:win32) %}
      @[Link("user32")]
      lib LibUser32Hotkeys
        MOD_ALT     = 0x0001_u32
        MOD_CONTROL = 0x0002_u32
        MOD_SHIFT   = 0x0004_u32
        MOD_WIN     = 0x0008_u32

        WM_HOTKEY = 0x0312_u32
        PM_REMOVE = 0x0001_u32

        struct Point
          x : LibC::Long
          y : LibC::Long
        end

        struct Msg
          hwnd     : Void*
          message  : UInt32
          w_param  : LibC::ULong
          l_param  : LibC::Long
          time     : UInt32
          pt       : Point
          # On modern Windows the struct includes a private DWORD too, but
          # PeekMessage doesn't read past `pt` so we keep the struct minimal.
        end

        fun register_hot_key = RegisterHotKey(hwnd : Void*, id : LibC::Int, fs_modifiers : UInt32, vk : UInt32) : LibC::Int
        fun unregister_hot_key = UnregisterHotKey(hwnd : Void*, id : LibC::Int) : LibC::Int
        fun peek_message_w = PeekMessageW(msg : Msg*, hwnd : Void*, msg_filter_min : UInt32, msg_filter_max : UInt32, remove : UInt32) : LibC::Int
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
        # Win32 RegisterHotKey is per-thread when hwnd=NULL: WM_HOTKEY arrives
        # in the message queue of the calling thread. We pin all hotkey state
        # to one dedicated thread that owns both registration and the WM
        # pump. Producer-side calls from any Crystal fiber push operations
        # into an ops queue protected by a Mutex; the pump drains both the
        # queue and the WM queue every tick.

        record Op, action : Symbol, accelerator : String, reply : Channel(Bool)

        @@handler  : (String -> Nil)? = nil
        @@ops_mu   = Mutex.new
        @@ops      = [] of Op
        @@id_to_acc = {} of LibC::Int => String
        @@acc_to_id = {} of String => LibC::Int
        @@next_id  : LibC::Int = 1
        @@stopped  : Bool = false

        def self.init(&handler : String -> Nil)
          return if @@started
          @@handler = handler
          ready = Channel(Nil).new(1)

          Fiber::ExecutionContext::Isolated.new("lune-hotkeys") do
            # Force this thread to have a message queue so RegisterHotKey
            # (called below from this thread) routes WM_HOTKEY back here.
            msg = LibUser32Hotkeys::Msg.new
            LibUser32Hotkeys.peek_message_w(pointerof(msg), Pointer(Void).null, 0_u32, 0_u32, 0_u32)
            ready.send(nil)

            until @@stopped
              # 1. Drain queued ops.
              ops = @@ops_mu.synchronize { o = @@ops.dup; @@ops.clear; o }
              ops.each { |op| process_op(op) }

              # 2. Drain WM messages.
              while LibUser32Hotkeys.peek_message_w(pointerof(msg), Pointer(Void).null, 0_u32, 0_u32, LibUser32Hotkeys::PM_REMOVE) != 0
                if msg.message == LibUser32Hotkeys::WM_HOTKEY
                  id = msg.w_param.to_i32
                  if acc = @@id_to_acc[id]?
                    @@handler.try(&.call(acc))
                  end
                end
              end

              sleep 10.milliseconds
            end
          end

          ready.receive
          @@started = true
        end

        def self.register(accelerator : String) : Bool
          return false unless @@started
          op = Op.new(:register, accelerator, Channel(Bool).new(1))
          @@ops_mu.synchronize { @@ops << op }
          op.reply.receive
        end

        def self.unregister(accelerator : String) : Bool
          return false unless @@started
          op = Op.new(:unregister, accelerator, Channel(Bool).new(1))
          @@ops_mu.synchronize { @@ops << op }
          op.reply.receive
        end

        def self.unregister_all : Nil
          return unless @@started
          # Fire-and-forget: don't wait on a reply Channel here. This is called
          # from the runner's shutdown loop on the webview Isolated thread (see
          # src/lune/runner.cr), where Channel#receive raises Concurrency-
          # disabled. The pump thread sees @@stopped on its next 10 ms tick and
          # exits; Windows reclaims any leftover RegisterHotKey registrations
          # automatically at process exit.
          @@stopped = true
          @@started = false
        end

        # Runs on the pump thread only.
        private def self.process_op(op : Op) : Nil
          case op.action
          when :register
            if parsed = parse_accelerator(op.accelerator)
              mods, vk = parsed
              if @@acc_to_id.has_key?(op.accelerator)
                op.reply.send(true)
                return
              end
              id = @@next_id
              @@next_id += 1
              if LibUser32Hotkeys.register_hot_key(Pointer(Void).null, id, mods, vk) != 0
                @@acc_to_id[op.accelerator] = id
                @@id_to_acc[id] = op.accelerator
                op.reply.send(true)
              else
                op.reply.send(false)
              end
            else
              op.reply.send(false)
            end
          when :unregister
            if id = @@acc_to_id.delete(op.accelerator)
              @@id_to_acc.delete(id)
              LibUser32Hotkeys.unregister_hot_key(Pointer(Void).null, id)
              op.reply.send(true)
            else
              op.reply.send(false)
            end
          when :unregister_all
            @@acc_to_id.each_value { |id| LibUser32Hotkeys.unregister_hot_key(Pointer(Void).null, id) }
            @@acc_to_id.clear
            @@id_to_acc.clear
            op.reply.send(true)
          end
        end

        # "Ctrl+Shift+K" / "Cmd+Space" / "Alt+F4" → {modifiers, virtual_key}.
        # Returns nil if the key portion can't be mapped to a VK code.
        private def self.parse_accelerator(accelerator : String) : {UInt32, UInt32}?
          mods = 0_u32
          key  = ""
          accelerator.split("+").each do |raw|
            part = raw.strip
            case part.downcase
            when "ctrl", "control"        then mods |= LibUser32Hotkeys::MOD_CONTROL
            when "shift"                  then mods |= LibUser32Hotkeys::MOD_SHIFT
            when "alt", "option"          then mods |= LibUser32Hotkeys::MOD_ALT
            when "win", "super", "cmd", "command" then mods |= LibUser32Hotkeys::MOD_WIN
            else key = part
            end
          end
          return nil if key.empty?
          vk = vk_for(key)
          return nil unless vk
          {mods, vk}
        end

        # Maps a key name to a Win32 virtual-key code. Single ASCII chars use
        # their uppercase ord directly (VK_A..VK_Z = 'A'..'Z' = 0x41..0x5A).
        private def self.vk_for(name : String) : UInt32?
          case name.downcase
          when "space"             then 0x20_u32
          when "return", "enter"   then 0x0D_u32
          when "tab"               then 0x09_u32
          when "backspace", "back" then 0x08_u32
          when "delete", "del"     then 0x2E_u32
          when "escape", "esc"     then 0x1B_u32
          when "left"              then 0x25_u32
          when "up"                then 0x26_u32
          when "right"             then 0x27_u32
          when "down"              then 0x28_u32
          when "home"              then 0x24_u32
          when "end"               then 0x23_u32
          when "pageup", "pgup"    then 0x21_u32
          when "pagedown", "pgdn"  then 0x22_u32
          when "insert"            then 0x2D_u32
          when /^f(\d+)$/
            n = $~[1].to_i
            n.in?(1..24) ? (0x70_u32 + (n - 1).to_u32) : nil
          when /^[a-z0-9]$/        then name.upcase[0].ord.to_u32
          else                          nil
          end
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
