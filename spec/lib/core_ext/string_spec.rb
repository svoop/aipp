require_relative '../../spec_helper'

describe String do

  describe :blank_to_nil do
    it "must convert blank to nil" do
      _("\n     \n         ".blank_to_nil).must_be :nil?
    end

    it "must leave non-blank untouched" do
      _("foobar".blank_to_nil).must_equal "foobar"
    end

    it "must leave non-blank with whitespace untouched" do
      _("\nfoo bar\n".blank_to_nil).must_equal "\nfoo bar\n"
    end
  end

  describe :cleanup do
    it "must replace double apostrophes" do
      _("the ''Terror'' was a fine ship".cleanup).must_equal 'the "Terror" was a fine ship'
    end

    it "must replace funky apostrophes and quotes" do
      _("from ’a‘ to “b”".cleanup).must_equal %q(from 'a' to "b")
    end

    it "must remove whitespace within quotes" do
      _('the " best " way to fly'.cleanup).must_equal 'the "best" way to fly'
      _(%Q(the " best\nway " to fly).cleanup).must_equal %Q(the "best\nway" to fly)
    end
  end

  describe :compact do
    it "must remove unneccessary whitespace" do
      _("  foo\n\nbar \r".compact).must_equal "foo\nbar"
      _("foo\n \nbar".compact).must_equal "foo\nbar"
      _("   ".compact).must_equal ""
      _("\n \r \v ".compact).must_equal ""
      _("okay".compact).must_equal "okay"
    end
  end

  describe :correlate do
    subject do
      %q(Truck "Montréal" en route on N 3 sud)
    end

    it "must recognize similar words with 5 or more characters" do
      _(subject.correlate("truck route")).must_equal 2
    end

    it "must recognize street denominators with 2 or more characters" do
      _(subject.correlate("truck N 3")).must_equal 2
    end

    it "must ignore whitespace in road identifiers" do
      _(subject.correlate("truck N3")).must_equal 2
    end

    it "must get rid of accents and similar decorations" do
      _(subject.correlate("truck Montreal")).must_equal 2
    end

    it "must downcase" do
      _(subject.correlate("truck montreal")).must_equal 2
    end

    it "must honor synonyms" do
      _(subject.correlate("truck south", ['south', 'sud'])).must_equal 2
    end

    it "must ignore words with less than 5 characters" do
      _(subject.correlate("en on for")).must_equal 0
    end
  end

  describe :to_ff do
    it "must convert normal float numbers as does to_f" do
      _("5".to_ff).must_equal "5".to_f
      _("5.1".to_ff).must_equal "5.1".to_f
      _(" 5.2 ".to_ff).must_equal " 5.2 ".to_f
    end

    it "must convert comma float numbers as well" do
      _("5,1".to_ff).must_equal "5.1".to_f
      _(" 5,2 ".to_ff).must_equal "5.2".to_f
    end
  end

  describe :full_strip do
    it "must behave like strip" do
      subject = "  foobar\t\t"
      _(subject.full_strip).must_equal subject.strip
    end

    it "must remove non-letterlike characters as well" do
      _(" - foobar :.".full_strip).must_equal "foobar"
    end
  end

  describe :first_match do
    subject { "A/A: 123.5 mhz" }

    it "returns the entire match if no capture group is present" do
      _(subject.first_match(/123\.5/)).must_equal "123.5"
    end

    it "returns the first matching capture group" do
      _(subject.first_match(/:\s+([\d.]+)/)).must_equal "123.5"
    end

    it "returns nil if the pattern doesn't match and no capture group is present" do
      _(subject.first_match(/121\.5/)).must_be :nil?
    end

    it "returns nil if the capture group doesn't match" do
      _(subject.first_match(/(121\.5)/)).must_be :nil?
    end

    it "returns default if the pattern doesn't match" do
      _(subject.first_match(/121\.5/, default: "123")).must_equal "123"
    end
  end

  describe :extract do
    subject do
      "This is #first# a test #second# of extract."
    end

    it "must return array of matches" do
      _(subject.extract(/#.+?#/)).must_equal ['#first#', '#second#']
    end

    it "removes matches from the string" do
      subject.extract(/#.+?#/)
      _(subject).must_equal "This is  a test  of extract."
    end
  end

  describe :strip_markup do
    subject do
      'This <br> contains &nbsp; <html lang="en"> markup &amp; entities.'
    end

    it "must strip tags and entities" do
      _(subject.strip_markup).must_equal 'This  contains   markup  entities.'
    end
  end

  describe :unglue do
    it "must insert spaces between camel glued words" do
      _("thisString has spaceProblems".unglue).must_equal "this String has space Problems"
    end

    it "must insert spaces between three-or-more-letter and number-only words" do
      _("the first123meters of D25".unglue).must_equal "the first 123 meters of D25"
    end
  end

end
