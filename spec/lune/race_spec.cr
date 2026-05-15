require "../spec_helper"
require "file_utils"

describe "Race checks" do
  it "keeps generated app code stable under concurrent generation" do
    binding_sets = [
      ["alpha", "beta"],
      ["gamma", "delta", "epsilon"],
      ["zeta"],
      ["sum", "ping", "pong"],
    ]

    generated = Channel(String).new

    binding_sets.each do |names|
      spawn do
        bindings = names.map do |name|
          Lune::BindingDef.new(
            name: name,
            namespace: "test",
            args: [] of String,
            return_type: "void",
            callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(nil) },
            internal: false,
            async: false
          )
        end

        40.times do
          js = Lune::Runtime::Generator.generate_app_js(bindings)
          generated.send(js)
        end
      end
    end

    results = [] of String
    (40 * binding_sets.size).times do
      results << generated.receive
    end

    results.each do |app_js|
      coherent = binding_sets.any? do |names|
        expected_bindings = names.map do |name|
          Lune::BindingDef.new(
            name: name,
            namespace: "test",
            args: [] of String,
            return_type: "void",
            callback: ->(_args : Array(JSON::Any)) { JSON::Any.new(nil) },
            internal: false,
            async: false
          )
        end

        app_js == Lune::Runtime::Generator.generate_app_js(expected_bindings)
      end

      coherent.should be_true
    end
  end
end
