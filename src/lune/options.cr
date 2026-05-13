module Lune
  class Options
    property title : String
    property width : Int32
    property height : Int32
    property hint : Webview::SizeHints
    property resizable : Bool
    property min_width : Int32?
    property min_height : Int32?
    property max_width : Int32?
    property max_height : Int32?
    property debug : Bool
    property on_navigate : (String -> Nil)?
    property on_close : (-> Nil)?

    def initialize
      @title = "Lune"
      @width = 1200
      @height = 800
      @hint = Webview::SizeHints::NONE
      @resizable = true
      @min_width = nil
      @min_height = nil
      @max_width = nil
      @max_height = nil
      @debug = false
      @on_navigate = nil
      @on_close = nil
    end
  end
end
