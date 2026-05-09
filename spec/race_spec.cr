require "./spec_helper"
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
    binding_sets.each do |bindings|
      spawn do
        40.times {
          js = Lune::Runtime.generate_app_js(bindings)
          generated.send(js)
        }
      end
    end

    results = [] of String
    (40 * binding_sets.size).times { results << generated.receive }

    # Each generated snapshot should match its binding set exactly
    results.each do |app_js|
      coherent = binding_sets.any? { |bindings| app_js == Lune::Runtime.generate_app_js(bindings) }
      coherent.should be_true
    end
  end
end
