{% if flag?(:win32) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      # LibUser32Hotkeys also holds the canonical Msg struct + PeekMessageW
      # declaration. win32/tray.cr reuses both — Crystal would otherwise error
      # on a second `fun peek_message_w = PeekMessageW(...)` with different
      # types in a different lib.
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
          hwnd : Void*
          message : UInt32
          # WPARAM/LPARAM are UINT_PTR/LONG_PTR — 8 bytes on 64-bit Windows.
          # LibC::ULong is only 4 bytes (LLP64), so we use explicit 64-bit types.
          # UInt64 forces 8-byte alignment, which inserts the 4-byte padding at
          # offset 12 that the real MSG struct has, placing w_param at offset 16.
          w_param : UInt64
          l_param : Int64
          time : UInt32
          pt : Point
          # On modern Windows the struct includes a private DWORD too, but
          # PeekMessage doesn't read past `pt` so we keep the struct minimal.
        end

        fun register_hot_key = RegisterHotKey(hwnd : Void*, id : LibC::Int, fs_modifiers : UInt32, vk : UInt32) : LibC::Int
        fun unregister_hot_key = UnregisterHotKey(hwnd : Void*, id : LibC::Int) : LibC::Int
        fun peek_message_w = PeekMessageW(msg : Msg*, hwnd : Void*, msg_filter_min : UInt32, msg_filter_max : UInt32, remove : UInt32) : LibC::Int
      end

      # Win32 RegisterHotKey is per-thread when hwnd=NULL: WM_HOTKEY arrives
      # in the message queue of the calling thread. We pin all hotkey state
      # to one dedicated thread that owns both registration and the WM
      # pump. Producer-side calls from any Crystal fiber push operations
      # into an ops queue protected by a Mutex; the pump drains both the
      # queue and the WM queue every tick.
      module Hotkeys
        record Op, action : Symbol, accelerator : String, reply : Channel(Bool)

        @@started : Bool = false
        @@handler : (String -> Nil)? = nil
        @@ops_mu = Mutex.new
        @@ops = [] of Op
        @@id_to_acc = {} of LibC::Int => String
        @@acc_to_id = {} of String => LibC::Int
        @@next_id : LibC::Int = 1
        @@stopped : Bool = false

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
          key = ""
          accelerator.split("+").each do |raw|
            part = raw.strip
            case part.downcase
            when "ctrl", "control"                then mods |= LibUser32Hotkeys::MOD_CONTROL
            when "shift"                          then mods |= LibUser32Hotkeys::MOD_SHIFT
            when "alt", "option"                  then mods |= LibUser32Hotkeys::MOD_ALT
            when "win", "super", "cmd", "command" then mods |= LibUser32Hotkeys::MOD_WIN
            else                                       key = part
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
          when /^[a-z0-9]$/ then name.upcase[0].ord.to_u32
          else                   nil
          end
        end
      end
    end
  end
{% end %}
