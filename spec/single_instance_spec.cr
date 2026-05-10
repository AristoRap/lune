require "./spec_helper"

describe Lune::SingleInstance do
  describe ".slug" do
    it "lowercases and replaces spaces" do
      Lune::SingleInstance.slug("My App").should eq "my-app"
    end

    it "collapses consecutive special chars into one hyphen" do
      Lune::SingleInstance.slug("foo--bar!!baz").should eq "foo-bar-baz"
    end

    it "strips leading and trailing hyphens" do
      Lune::SingleInstance.slug("  My App  ").should eq "my-app"
    end

    it "falls back to 'app' for an empty/symbol-only title" do
      Lune::SingleInstance.slug("!!!").should eq "app"
    end
  end

  describe ".acquire" do
    it "returns a file when the lock is available" do
      dir = File.tempname("lune-lock-test")
      slug = "test-#{Random::Secure.hex(4)}"
      lock = Lune::SingleInstance.acquire(slug, dir)
      lock.should_not be_nil
      lock.try(&.close)
      FileUtils.rm_rf(dir)
    end

    it "returns nil when the lock is already held" do
      dir = File.tempname("lune-lock-test")
      slug = "test-#{Random::Secure.hex(4)}"

      lock1 = Lune::SingleInstance.acquire(slug, dir)
      lock1.should_not be_nil

      lock2 = Lune::SingleInstance.acquire(slug, dir)
      lock2.should be_nil

      lock1.try(&.close)
      FileUtils.rm_rf(dir)
    end

    it "allows re-acquisition after the lock is released" do
      dir = File.tempname("lune-lock-test")
      slug = "test-#{Random::Secure.hex(4)}"

      lock1 = Lune::SingleInstance.acquire(slug, dir)
      lock1.should_not be_nil
      lock1.try(&.close)

      lock2 = Lune::SingleInstance.acquire(slug, dir)
      lock2.should_not be_nil
      lock2.try(&.close)

      FileUtils.rm_rf(dir)
    end
  end
end
