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

  describe ".listen + .forward round trip" do
    # Pending in CI: the Isolated listener thread blocks in server.accept?,
    # and on Linux closing the server during `ensure` doesn't always
    # interrupt the kernel-level accept syscall. The leaked thread keeps
    # `crystal spec` from exiting, hanging CI. Verified working manually on
    # macOS; on Linux, run only locally. Re-enable once `Lune::DeepLinkIPC`
    # exposes a clean `stop` that's portable.
    pending "delivers a URL from a forwarder to a listener"
  end
end
