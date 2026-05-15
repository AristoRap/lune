module Lune
  module Runtime
    module Bindings
      def self.filter(bindings : Array(Binding), capabilities : Array(String)?) : Array(Binding)
        return bindings if capabilities.nil?
        bindings.select { |b| capabilities.includes?(b.method.lchop("__lune.")) }
      end
    end
  end
end
