require_relative '../../spec_helper'

describe String do

  describe :blank_to_nil do
    it "must convert blank to nil" do
      "\n     \n         ".blank_to_nil.must_be :nil?
    end

    it "must leave non-blank untouched" do
      "foobar".blank_to_nil.must_equal "foobar"
    end

    it "must leave non-blank with whitespace untouched" do
      "\nfoo bar\n".blank_to_nil.must_equal "\nfoo bar\n"
    end
  end

  describe :compact do
    it "must remove unneccessary whitespace" do
      "  foo\n\nbar \r".compact.must_equal "foo\nbar"
      "foo\n \nbar".compact.must_equal "foo\nbar"
      "   ".compact.must_equal ""
      "\n \r \v ".compact.must_equal ""
      "okay".compact.must_equal "okay"
    end
  end

  describe :cleanup do
    it "must replace double apostrophes" do
      "the ''Terror'' was a fine ship".cleanup.must_equal 'the "Terror" was a fine ship'
    end

    it "must replace funky apostrophes and quotes" do
      "from ’a‘ to “b”".cleanup.must_equal %q(from 'a' to "b")
    end

    it "must remove whitespace within quotes" do
      'the " best " way to fly'.cleanup.must_equal 'the "best" way to fly'
      %Q(the " best\nway " to fly).cleanup.must_equal %Q(the "best\nway" to fly) 
    end
  end

  describe :unglue do
    it "must insert spaces between camel glued words" do
      "thisString has spaceProblems".unglue.must_equal "this String has space Problems"
    end

    it "must insert spaces between three-or-more-letter and number-only words" do
      "the first123meters of D25".unglue.must_equal "the first 123 meters of D25"
    end
  end

  describe :correlate do
    subject do
      %q(Truck "Montréal" en route on N 3 sud)
    end

    it "must recognize similar words with 5 or more characters" do
      subject.correlate("truck route").must_equal 2
    end

    it "must recognize street denominators with 2 or more characters" do
      subject.correlate("truck N 3").must_equal 2
    end

    it "must ignore whitespace in road identifiers" do
      subject.correlate("truck N3").must_equal 2
    end

    it "must get rid of accents and similar decorations" do
      subject.correlate("truck Montreal").must_equal 2
    end

    it "must downcase" do
      subject.correlate("truck montreal").must_equal 2
    end

    it "must honor synonyms" do
      subject.correlate("truck south", ['south', 'sud']).must_equal 2
    end

    it "must ignore words with less than 5 characters" do
      subject.correlate("en on for").must_equal 0
    end
  end

end
