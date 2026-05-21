{% if flag?(:darwin) %}
  module Lune
    module Native
      EVFILT_VNODE =         -4_i16
      NOTE_DELETE  = 0x00000001_u32
      NOTE_WRITE   = 0x00000002_u32
      NOTE_ATTRIB  = 0x00000008_u32
      NOTE_RENAME  = 0x00000020_u32
      O_EVTONLY    =         0x8000
    end
  end
{% end %}
