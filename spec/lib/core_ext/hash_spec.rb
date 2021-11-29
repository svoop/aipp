require_relative '../../spec_helper'

describe Hash do

  describe :metch do
    subject do
      { /aa/ => :aa, /a/ => :a, 'b' => :b }
    end

    it "must return value of matching regexp key" do
      _(subject.metch('abc')).must_equal :a
    end

    it "must return value of equal non-regexp key" do
      _(subject.metch('b')).must_equal :b
    end

    it "fails with KeyError if nothing matches" do
      _{ subject.metch('bcd') }.must_raise KeyError
    end

    it "returns fallback value if nothing matches" do
      _(subject.metch('x', :foobar)).must_equal :foobar
      _(subject.metch('x', nil)).must_be :nil?
     end
  end

  describe :to_remarks do
    it "upcases keys" do
      _({ 'key' => 'value' }.to_remarks).must_equal "**KEY**\nvalue"
    end

    it "converts keys and values to strings" do
      _({ 111 => 222 }.to_remarks).must_equal "**111**\n222"
    end

    it "removes nil values" do
      _({ 'key' => 'value', 'ignore' => nil }.to_remarks).must_equal "**KEY**\nvalue"
    end

    it "remvoes blank values" do
      _({ 'key' => 'value', 'ignore' => '' }.to_remarks).must_equal "**KEY**\nvalue"
    end

    it "returns nil if no content remains" do
      _({ 'ignore' => nil }.to_remarks).must_be :nil?
    end
  end

end
