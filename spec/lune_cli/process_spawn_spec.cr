require "../spec_helper"

describe LuneCLI::ProcessSpawn do
  describe ".wrap" do
    {% if flag?(:win32) %}
      it "wraps the command in `cmd /c` on Windows" do
        program, args = LuneCLI::ProcessSpawn.wrap("npm.cmd", ["install"])
        program.should eq("cmd")
        args.should eq(["/c", "npm.cmd", "install"])
      end

      it "wraps PATHEXT-resolved bare commands too" do
        program, args = LuneCLI::ProcessSpawn.wrap("npm", ["run", "build"])
        program.should eq("cmd")
        args.should eq(["/c", "npm", "run", "build"])
      end

      it "preserves an empty args array" do
        program, args = LuneCLI::ProcessSpawn.wrap("git", [] of String)
        program.should eq("cmd")
        args.should eq(["/c", "git"])
      end
    {% else %}
      it "returns the command unchanged on non-Windows" do
        program, args = LuneCLI::ProcessSpawn.wrap("npm", ["run", "build"])
        program.should eq("npm")
        args.should eq(["run", "build"])
      end

      it "preserves an empty args array" do
        program, args = LuneCLI::ProcessSpawn.wrap("git", [] of String)
        program.should eq("git")
        args.should eq([] of String)
      end
    {% end %}
  end
end
