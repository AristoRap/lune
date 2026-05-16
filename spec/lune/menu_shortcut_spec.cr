require "../spec_helper"

describe Lune::MenuShortcut do
  describe ".parse" do
    describe "single-character keys" do
      it "parses cmd+n" do
        p = Lune::MenuShortcut.parse("cmd+n")
        p.key.should eq("n")
        p.modifiers.should eq(Lune::MenuShortcut::CMD)
      end

      it "parses cmd+q" do
        p = Lune::MenuShortcut.parse("cmd+q")
        p.key.should eq("q")
        p.modifiers.should eq(Lune::MenuShortcut::CMD)
      end

      it "is case-insensitive for modifier tokens" do
        p = Lune::MenuShortcut.parse("CMD+N")
        p.key.should eq("n")
        p.modifiers.should eq(Lune::MenuShortcut::CMD)
      end
    end

    describe "shift modifier" do
      it "uppercases single-character key when shift is present" do
        p = Lune::MenuShortcut.parse("cmd+shift+z")
        p.key.should eq("Z")
        p.modifiers.should eq(Lune::MenuShortcut::CMD | Lune::MenuShortcut::SHIFT)
      end

      it "does not uppercase named keys (e.g. return) with shift" do
        p = Lune::MenuShortcut.parse("cmd+shift+return")
        p.key.should eq("\r")
        p.modifiers.should eq(Lune::MenuShortcut::CMD | Lune::MenuShortcut::SHIFT)
      end
    end

    describe "modifier aliases" do
      it "accepts 'command' as alias for 'cmd'" do
        p = Lune::MenuShortcut.parse("command+s")
        p.modifiers.should eq(Lune::MenuShortcut::CMD)
      end

      it "accepts 'opt' for option" do
        p = Lune::MenuShortcut.parse("opt+a")
        p.modifiers.should eq(Lune::MenuShortcut::OPT)
      end

      it "accepts 'alt' for option" do
        p = Lune::MenuShortcut.parse("alt+a")
        p.modifiers.should eq(Lune::MenuShortcut::OPT)
      end

      it "accepts 'option' for option" do
        p = Lune::MenuShortcut.parse("option+a")
        p.modifiers.should eq(Lune::MenuShortcut::OPT)
      end

      it "accepts 'control' as alias for 'ctrl'" do
        p = Lune::MenuShortcut.parse("control+a")
        p.modifiers.should eq(Lune::MenuShortcut::CTRL)
      end
    end

    describe "multiple modifiers" do
      it "combines cmd and shift" do
        p = Lune::MenuShortcut.parse("cmd+shift+z")
        p.modifiers.should eq(Lune::MenuShortcut::CMD | Lune::MenuShortcut::SHIFT)
      end

      it "combines cmd, shift, and opt" do
        p = Lune::MenuShortcut.parse("cmd+shift+opt+a")
        p.key.should eq("A")
        p.modifiers.should eq(
          Lune::MenuShortcut::CMD | Lune::MenuShortcut::SHIFT | Lune::MenuShortcut::OPT
        )
      end

      it "combines ctrl and opt" do
        p = Lune::MenuShortcut.parse("ctrl+opt+t")
        p.key.should eq("t")
        p.modifiers.should eq(Lune::MenuShortcut::CTRL | Lune::MenuShortcut::OPT)
      end
    end

    describe "named keys" do
      it "maps 'return'" do
        Lune::MenuShortcut.parse("cmd+return").key.should eq("\r")
      end

      it "maps 'enter' the same as 'return'" do
        Lune::MenuShortcut.parse("cmd+enter").key.should eq("\r")
      end

      it "maps 'tab'" do
        Lune::MenuShortcut.parse("cmd+tab").key.should eq("\t")
      end

      it "maps 'escape'" do
        Lune::MenuShortcut.parse("escape").key.should eq("\e")
      end

      it "maps 'esc'" do
        Lune::MenuShortcut.parse("esc").key.should eq("\e")
      end

      it "maps 'delete'" do
        Lune::MenuShortcut.parse("cmd+delete").key.should eq("\u{7f}")
      end

      it "maps 'backspace' the same as 'delete'" do
        Lune::MenuShortcut.parse("cmd+backspace").key.should eq("\u{7f}")
      end

      it "maps 'space'" do
        Lune::MenuShortcut.parse("cmd+space").key.should eq(" ")
      end

      it "maps arrow keys" do
        Lune::MenuShortcut.parse("cmd+up").key.should eq("\u{F700}")
        Lune::MenuShortcut.parse("cmd+down").key.should eq("\u{F701}")
        Lune::MenuShortcut.parse("cmd+left").key.should eq("\u{F702}")
        Lune::MenuShortcut.parse("cmd+right").key.should eq("\u{F703}")
      end

      it "maps home and end" do
        Lune::MenuShortcut.parse("cmd+home").key.should eq("\u{F729}")
        Lune::MenuShortcut.parse("cmd+end").key.should eq("\u{F72B}")
      end

      it "maps page up and page down" do
        Lune::MenuShortcut.parse("cmd+pageup").key.should eq("\u{F72C}")
        Lune::MenuShortcut.parse("cmd+pagedown").key.should eq("\u{F72D}")
      end

      it "maps f1 through f12" do
        Lune::MenuShortcut.parse("f1").key.should eq("\u{F704}")
        Lune::MenuShortcut.parse("f12").key.should eq("\u{F70F}")
        Lune::MenuShortcut.parse("cmd+f5").key.should eq("\u{F708}")
      end
    end

    describe "no modifiers" do
      it "returns zero modifiers for a bare key" do
        p = Lune::MenuShortcut.parse("a")
        p.key.should eq("a")
        p.modifiers.should eq(0_u64)
      end
    end

    describe "modifier flag values" do
      it "CMD is bit 20" do
        Lune::MenuShortcut::CMD.should eq(1_u64 << 20)
      end

      it "SHIFT is bit 17" do
        Lune::MenuShortcut::SHIFT.should eq(1_u64 << 17)
      end

      it "CTRL is bit 18" do
        Lune::MenuShortcut::CTRL.should eq(1_u64 << 18)
      end

      it "OPT is bit 19" do
        Lune::MenuShortcut::OPT.should eq(1_u64 << 19)
      end
    end
  end
end
