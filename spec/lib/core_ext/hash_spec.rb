require_relative '../../spec_helper'

describe Hash do

  describe :metch do
    subject do
      { /aa/ => :aa, /a/ => :a, 'b' => :b }
    end

    it "must return value of matching regexp key" do
      subject.metch('abc').must_equal :a
    end

    it "must return value of equal non-regexp key" do
      subject.metch('b').must_equal :b
    end

    it "fails with KeyError if nothing matches" do
      -> { subject.metch('bcd') }.must_raise KeyError
    end

    it "returns fallback value if nothing matches" do
      subject.metch('x', :foobar).must_equal :foobar
    end
  end

end
