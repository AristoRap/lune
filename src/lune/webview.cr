require "webview"
require "json"

module Lune
  # Spec-friendly abstraction over the methods Lune's bridge layer uses
  # against a webview. `Webview::Webview` includes this naturally because
  # all the methods are now first-class in the fork; spec fakes implement
  # it manually so the bridge can be tested without spinning up a real
  # webview.
  module WebviewLike
    abstract def bind_deferred(name : String, &block : String, Array(JSON::Any) -> Nil)
    abstract def dispatch(&f : ->)
    abstract def resolve(seq : String, status : Int32, result : String)
    abstract def eval(js : String)
  end
end

module Webview
  class Webview
    include ::Lune::WebviewLike
  end
end
