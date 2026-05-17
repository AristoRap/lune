require "../spec_helper"

describe Lune::Options::Menu::Shortcut do
  describe ".parse" do
    describe "single-character keys" do
      it "parses cmd+n" do
        p = Lune::Options::Menu::Shortcut.parse("cmd+n")
        p.key.should eq("n")
        p.modifiers.should eq(Lune::Options::Menu::Shortcut::CMD)
      end

      it "parses cmd+q" do
        p = Lune::Options::Menu::Shortcut.parse("cmd+q")
        p.key.should eq("q")
        p.modifiers.should eq(Lune::Options::Menu::Shortcut::CMD)
      end

      it "is case-insensitive for modifier tokens" do
        p = Lune::Options::Menu::Shortcut.parse("CMD+N")
        p.key.should eq("n")
        p.modifiers.should eq(Lune::Options::Menu::Shortcut::CMD)
      end
    end

    describe "shift modifier" do
      it "uppercases single-character key when shift is present" do
        p = Lune::Options::Menu::Shortcut.parse("cmd+shift+z")
        p.key.should eq("Z")
        p.modifiers.should eq(Lune::Options::Menu::Shortcut::CMD | Lune::Options::Menu::Shortcut::SHIFT)
      end

      it "does not uppercase named keys (e.g. return) with shift" do
        p = Lune::Options::Menu::Shortcut.parse("cmd+shift+return")
        p.key.should eq("\r")
        p.modifiers.should eq(Lune::Options::Menu::Shortcut::CMD | Lune::Options::Menu::Shortcut::SHIFT)
      end
    end

    describe "modifier aliases" do
      it "accepts 'command' as alias for 'cmd'" do
        p = Lune::Options::Menu::Shortcut.parse("command+s")
        p.modifiers.should eq(Lune::Options::Menu::Shortcut::CMD)
      end

      it "accepts 'opt' for option" do
        p = Lune::Options::Menu::Shortcut.parse("opt+a")
        p.modifiers.should eq(Lune::Options::Menu::Shortcut::OPT)
      end

      it "accepts 'alt' for option" do
        p = Lune::Options::Menu::Shortcut.parse("alt+a")
        p.modifiers.should eq(Lune::Options::Menu::Shortcut::OPT)
      end

      it "accepts 'option' for option" do
        p = Lune::Options::Menu::Shortcut.parse("option+a")
        p.modifiers.should eq(Lune::Options::Menu::Shortcut::OPT)
      end

      it "accepts 'control' as alias for 'ctrl'" do
        p = Lune::Options::Menu::Shortcut.parse("control+a")
        p.modifiers.should eq(Lune::Options::Menu::Shortcut::CTRL)
      end
    end

    describe "multiple modifiers" do
      it "combines cmd and shift" do
        p = Lune::Options::Menu::Shortcut.parse("cmd+shift+z")
        p.modifiers.should eq(Lune::Options::Menu::Shortcut::CMD | Lune::Options::Menu::Shortcut::SHIFT)
      end

      it "combines cmd, shift, and opt" do
        p = Lune::Options::Menu::Shortcut.parse("cmd+shift+opt+a")
        p.key.should eq("A")
        p.modifiers.should eq(
          Lune::Options::Menu::Shortcut::CMD | Lune::Options::Menu::Shortcut::SHIFT | Lune::Options::Menu::Shortcut::OPT
        )
      end

      it "combines ctrl and opt" do
        p = Lune::Options::Menu::Shortcut.parse("ctrl+opt+t")
        p.key.should eq("t")
        p.modifiers.should eq(Lune::Options::Menu::Shortcut::CTRL | Lune::Options::Menu::Shortcut::OPT)
      end
    end

    describe "named keys" do
      it "maps 'return'" do
        Lune::Options::Menu::Shortcut.parse("cmd+return").key.should eq("\r")
      end

      it "maps 'enter' the same as 'return'" do
        Lune::Options::Menu::Shortcut.parse("cmd+enter").key.should eq("\r")
      end

      it "maps 'tab'" do
        Lune::Options::Menu::Shortcut.parse("cmd+tab").key.should eq("\t")
      end

      it "maps 'escape'" do
        Lune::Options::Menu::Shortcut.parse("escape").key.should eq("\e")
      end

      it "maps 'esc'" do
        Lune::Options::Menu::Shortcut.parse("esc").key.should eq("\e")
      end

      it "maps 'delete'" do
        Lune::Options::Menu::Shortcut.parse("cmd+delete").key.should eq("\u{7f}")
      end

      it "maps 'backspace' the same as 'delete'" do
        Lune::Options::Menu::Shortcut.parse("cmd+backspace").key.should eq("\u{7f}")
      end

      it "maps 'space'" do
        Lune::Options::Menu::Shortcut.parse("cmd+space").key.should eq(" ")
      end

      it "maps arrow keys" do
        Lune::Options::Menu::Shortcut.parse("cmd+up").key.should eq("\u{F700}")
        Lune::Options::Menu::Shortcut.parse("cmd+down").key.should eq("\u{F701}")
        Lune::Options::Menu::Shortcut.parse("cmd+left").key.should eq("\u{F702}")
        Lune::Options::Menu::Shortcut.parse("cmd+right").key.should eq("\u{F703}")
      end

      it "maps home and end" do
        Lune::Options::Menu::Shortcut.parse("cmd+home").key.should eq("\u{F729}")
        Lune::Options::Menu::Shortcut.parse("cmd+end").key.should eq("\u{F72B}")
      end

      it "maps page up and page down" do
        Lune::Options::Menu::Shortcut.parse("cmd+pageup").key.should eq("\u{F72C}")
        Lune::Options::Menu::Shortcut.parse("cmd+pagedown").key.should eq("\u{F72D}")
      end

      it "maps f1 through f12" do
        Lune::Options::Menu::Shortcut.parse("f1").key.should eq("\u{F704}")
        Lune::Options::Menu::Shortcut.parse("f12").key.should eq("\u{F70F}")
        Lune::Options::Menu::Shortcut.parse("cmd+f5").key.should eq("\u{F708}")
      end
    end

    describe "no modifiers" do
      it "returns zero modifiers for a bare key" do
        p = Lune::Options::Menu::Shortcut.parse("a")
        p.key.should eq("a")
        p.modifiers.should eq(0_u64)
      end
    end

    describe "modifier flag values" do
      it "CMD is bit 20" do
        Lune::Options::Menu::Shortcut::CMD.should eq(1_u64 << 20)
      end

      it "SHIFT is bit 17" do
        Lune::Options::Menu::Shortcut::SHIFT.should eq(1_u64 << 17)
      end

      it "CTRL is bit 18" do
        Lune::Options::Menu::Shortcut::CTRL.should eq(1_u64 << 18)
      end

      it "OPT is bit 19" do
        Lune::Options::Menu::Shortcut::OPT.should eq(1_u64 << 19)
      end
    end
  end
end
