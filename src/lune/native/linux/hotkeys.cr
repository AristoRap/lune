{% if flag?(:linux) && !flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      @[Link("X11")]
      lib LibX11Hotkeys
        alias XDisplay = Void*
        alias XWindow = LibC::ULong

        struct XEvent
          type : LibC::Int
          pad : StaticArray(LibC::Long, 23)
        end

        struct XKeyEvent
          type : LibC::Int
          serial : LibC::ULong
          send_event : LibC::Int
          display : XDisplay
          window : XWindow
          root : XWindow
          subwindow : XWindow
          time : LibC::ULong
          x : LibC::Int
          y : LibC::Int
          x_root : LibC::Int
          y_root : LibC::Int
          state : LibC::UInt
          keycode : LibC::UInt
          same_screen : LibC::Int
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
    end
  end
{% end %}
