require "../../spec_helper"

describe Lune::Native::Notify do
  before_each { Lune::Native::NotifyMock.reset }

  describe ".show" do
    it "records a show call" do
      Lune::Native::Notify.show("Hello", "This is a notification")
      Lune::Native::NotifyMock.calls.should contain(:show)
    end

    it "records the title" do
      Lune::Native::Notify.show("Update available", "Version 2.0 is ready")
      Lune::Native::NotifyMock.last_title.should eq("Update available")
    end

    it "records the body" do
      Lune::Native::Notify.show("Update available", "Version 2.0 is ready")
      Lune::Native::NotifyMock.last_body.should eq("Version 2.0 is ready")
    end
  end
end
