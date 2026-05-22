module Lune
  module Plugins
    class Window < Lune::Plugin
      include Lune::Bindable

      DESCRIPTOR = Descriptor.new(id: :window, label: "Window")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @handle : Void* = Pointer(Void).null

      def setup(ctx : SetupCtx) : Nil
        @handle = ctx.handle
      end

      @[Lune::Bind]
      def minimize : Nil
        Lune::Native::Window.minimize(@handle)
      end

      @[Lune::Bind]
      def maximize : Nil
        Lune::Native::Window.maximize(@handle)
      end

      @[Lune::Bind]
      def center : Nil
        Lune::Native::Window.center(@handle)
      end

      @[Lune::Bind]
      def hide : Nil
        Lune::Native::Window.hide(@handle)
      end

      @[Lune::Bind]
      def show : Nil
        Lune::Native::Window.show(@handle)
      end

      @[Lune::Bind]
      def set_title(title : String) : Nil
        Lune::Native::Window.set_title(@handle, title)
      end

      @[Lune::Bind]
      def set_size(width : Int32, height : Int32) : Nil
        Lune::Native::Window.set_size(@handle, width, height)
      end
    end
  end
end
