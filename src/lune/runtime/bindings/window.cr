require "json"

module Lune
  module Runtime
    module Bindings
      class Window
        include Lune::Installable

        def initialize(@handle : Void*)
        end

        def install(app : Lune::App)
          minimize(app)
          maximize(app)
          set_title(app)
          set_size(app)
          center(app)
        end

        private def minimize(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.minimize",
            args: [] of String,
            return_type: "Nil",
            async: false,
            runtime: true
          ) do |_args|
            Lune::Native::Window.minimize(@handle)
            JSON::Any.new(nil)
          end
        end

        private def maximize(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.maximize",
            args: [] of String,
            return_type: "Nil",
            async: false,
            runtime: true
          ) do |_args|
            Lune::Native::Window.maximize(@handle)
            JSON::Any.new(nil)
          end
        end

        private def set_title(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.setTitle",
            args: ["String"],
            return_type: "Nil",
            async: false,
            runtime: true
          ) do |args|
            Lune::Native::Window.set_title(@handle, args[0].as_s)
            JSON::Any.new(nil)
          end
        end

        private def set_size(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.setSize",
            args: ["Int32", "Int32"],
            return_type: "Nil",
            async: false,
            runtime: true
          ) do |args|
            Lune::Native::Window.set_size(@handle, args[0].as_i, args[1].as_i)
            JSON::Any.new(nil)
          end
        end

        private def center(app : Lune::App)
          app.bind(
            namespace: "runtime",
            method: "__lune.center",
            args: [] of String,
            return_type: "Nil",
            async: false,
            runtime: true
          ) do |_args|
            Lune::Native::Window.center(@handle)
            JSON::Any.new(nil)
          end
        end
      end
    end
  end
end
