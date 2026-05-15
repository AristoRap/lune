require "../../spec_helper"

describe Lune::Native::Dialog do
  before_each { Lune::Native::DialogMock.reset }

  describe ".open_file" do
    it "returns the stubbed path when the user picks a file" do
      Lune::Native::DialogMock.stub_open("/home/user/photo.png")
      Lune::Native::Dialog.open_file("Pick a file").should eq("/home/user/photo.png")
    end

    it "returns nil when the dialog is cancelled" do
      Lune::Native::DialogMock.stub_open(nil)
      Lune::Native::Dialog.open_file("Pick a file").should be_nil
    end

    it "records the call with the given title" do
      Lune::Native::Dialog.open_file("Select Image")
      call = Lune::Native::DialogMock.calls.find { |c| c.method == :open_file }
      call.should_not be_nil
      call.not_nil!.title.should eq("Select Image")
    end
  end

  describe ".save_file" do
    it "returns the stubbed path when the user picks a destination" do
      Lune::Native::DialogMock.stub_save("/home/user/report.csv")
      Lune::Native::Dialog.save_file("Save As", "report.csv").should eq("/home/user/report.csv")
    end

    it "returns nil when the dialog is cancelled" do
      Lune::Native::DialogMock.stub_save(nil)
      Lune::Native::Dialog.save_file("Save As", "report.csv").should be_nil
    end

    it "records the call with title and default name" do
      Lune::Native::Dialog.save_file("Export", "data.json")
      call = Lune::Native::DialogMock.calls.find { |c| c.method == :save_file }
      call.should_not be_nil
      call.not_nil!.title.should eq("Export")
      call.not_nil!.default_name.should eq("data.json")
    end
  end
end
