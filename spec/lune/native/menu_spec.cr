require "../../spec_helper"

describe Lune::Native::Menu do
  before_each { Lune::Native::MenuMock.reset }

  describe ".setup_default" do
    it "records a setup_default call" do
      Lune::Native::Menu.setup_default("My App")
      Lune::Native::MenuMock.calls.should contain(:setup_default)
    end

    it "records the app name" do
      Lune::Native::Menu.setup_default("My App")
      Lune::Native::MenuMock.last_app_name.should eq("My App")
    end

    it "accepts an empty app name" do
      Lune::Native::Menu.setup_default("")
      Lune::Native::MenuMock.calls.should contain(:setup_default)
      Lune::Native::MenuMock.last_app_name.should eq("")
    end

    it "records the most recent call when called multiple times" do
      Lune::Native::Menu.setup_default("First")
      Lune::Native::Menu.setup_default("Second")
      Lune::Native::MenuMock.last_app_name.should eq("Second")
      Lune::Native::MenuMock.calls.size.should eq(2)
    end
  end
end
