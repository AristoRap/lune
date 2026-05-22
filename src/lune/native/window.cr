module Lune
  module Native
    # Public surface assembled in sibling files:
    #   - mock/window.cr     WindowMock + Window delegates (test mode)
    #   - darwin/window.cr   LibNativeWindow (NSWindow .m shim) + full impl
    #   - linux/window.cr    LibNativeWindow (GtkWindow .c shim) + impl
    #                        (most darwin-only methods no-op here)
    #   - win32/window.cr    LibUser32 (basic move/title/show — no .o shim) +
    #                        impl (darwin-only methods no-op)
    #
    # Shared drop / close callback registries live here so per-OS files can
    # pin the boxed Procs without re-declaring the maps:
    #   - @@drop_boxes / @@drop_pos_boxes: keyed by window handle so multiple
    #     windows can each have a live drop callback without one overwriting
    #     another's GC pin.
    #   - @@close_procs: holds Crystal close-callback procs until they fire.
    module Window
      @@drop_boxes = {} of Void* => Pointer(Void)
      @@drop_pos_boxes = {} of Void* => Pointer(Void)
      @@close_procs = {} of Void* => Proc(Nil)
    end
  end
end
