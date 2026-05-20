require "../../spec_helper"

describe Lune::Native::Notifications do
  before_each { Lune::Native::NotificationsMock.reset }

  describe ".show" do
    it "records a show call" do
      Lune::Native::Notifications.show("Hello", "This is a notification")
      Lune::Native::NotificationsMock.calls.should contain(:show)
    end

    it "records the title" do
      Lune::Native::Notifications.show("Update available", "Version 2.0 is ready")
      Lune::Native::NotificationsMock.last_title.should eq("Update available")
    end

    it "records the body" do
      Lune::Native::Notifications.show("Update available", "Version 2.0 is ready")
      Lune::Native::NotificationsMock.last_body.should eq("Version 2.0 is ready")
    end
  end
end
