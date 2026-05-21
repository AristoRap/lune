{% if flag?(:linux) %}
  module Lune
    module Native
      lib LibInotify
        IN_MODIFY      = 0x00000002_u32
        IN_ATTRIB      = 0x00000004_u32
        IN_MOVED_FROM  = 0x00000040_u32
        IN_MOVED_TO    = 0x00000080_u32
        IN_CREATE      = 0x00000100_u32
        IN_DELETE      = 0x00000200_u32
        IN_DELETE_SELF = 0x00000400_u32
        IN_MOVE_SELF   = 0x00000800_u32

        struct InotifyEvent
          wd : LibC::Int
          mask : LibC::UInt
          cookie : LibC::UInt
          len : LibC::UInt
        end

        fun inotify_init : LibC::Int
        fun inotify_add_watch(fd : LibC::Int, path : LibC::Char*, mask : LibC::UInt) : LibC::Int
        fun inotify_rm_watch(fd : LibC::Int, wd : LibC::Int) : LibC::Int
      end
    end
  end
{% end %}
