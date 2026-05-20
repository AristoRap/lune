require "../spec_helper"

describe Lune::DeepLinkIPC do
  describe ".socket_path" do
    it "is stable for the same app name" do
      Lune::DeepLinkIPC.socket_path("My App").should eq(Lune::DeepLinkIPC.socket_path("My App"))
    end

    it "differs for different app names" do
      Lune::DeepLinkIPC.socket_path("App A").should_not eq(Lune::DeepLinkIPC.socket_path("App B"))
    end

    it "slugifies the app name into the filename" do
      Lune::DeepLinkIPC.socket_path("My Cool App!").should match(/lune-my-cool-app\.sock$/)
    end

    it "falls back to 'lune' for empty/non-alphanumeric titles" do
      Lune::DeepLinkIPC.socket_path("!!!").should match(/lune-lune\.sock$/)
    end
  end

  describe ".forward" do
    it "returns false when no socket exists" do
      Lune::DeepLinkIPC.forward("myapp://x", "nonexistent-app-#{Random.new.hex(8)}").should be_false
    end
  end

  {% if flag?(:linux) || flag?(:darwin) %}
    describe ".listen + .forward round trip" do
      it "delivers a URL from a forwarder to a listener" do
        app_name = "lune-ipc-test-#{Random.new.hex(6)}"
        received : String? = nil
        done = Channel(Nil).new(1)

        server = Lune::DeepLinkIPC.listen(app_name) do |url|
          received = url
          done.send(nil)
        end
        server.should_not be_nil

        begin
          Lune::DeepLinkIPC.forward("myapp://hello", app_name).should be_true
          # Wait up to 2s for the listener fiber to process the message.
          select
          when done.receive
          when timeout(2.seconds)
          end
          received.should eq("myapp://hello")
        ensure
          server.try(&.close)
          File.delete?(Lune::DeepLinkIPC.socket_path(app_name))
        end
      end
    end
  {% end %}
end
