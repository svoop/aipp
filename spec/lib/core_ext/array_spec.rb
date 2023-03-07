require_relative '../../spec_helper'

describe Array do

  describe :constantize do
    it "returns non-namespaced class" do
      _(%w(MiniTest).constantize).must_equal MiniTest
    end

    it "returns namespaced class" do
      _(%w(AIPP Border).constantize).must_equal AIPP::Border
    end

    it "converts elements to string beforehand" do
      _(%i(AIPP Border).constantize).must_equal AIPP::Border
    end
  end

  describe :consolidate_ranges do
    it "leaves empty array untouched" do
      _([].consolidate_ranges).must_equal []
    end

    it "leaves array with only one element untouched" do
      _([7..13].consolidate_ranges).must_equal [7..13]
    end

    it "consolidates identical ranges" do
      _([7..13, 7..13].consolidate_ranges).must_equal [7..13]
    end

    it "consolidates overlapping ranges" do
      _([7..13, 7..14].consolidate_ranges).must_equal [7..14]
      _([7..13, 6..13].consolidate_ranges).must_equal [6..13]
      _([7..13, 6..14].consolidate_ranges).must_equal [6..14]
    end

    it "consolidates adjacent ranges" do
      _([7..13, 13..15].consolidate_ranges).must_equal [7..15]
    end

    it "separates not overlapping ranges" do
      _([7..13, 14..17].consolidate_ranges).must_equal [7..13, 14..17]
    end

    it "consolidates complex ranges" do
      _([15..17, 7..11, 12..13, 8..12, 12..13].consolidate_ranges).must_equal [7..13, 15..17]
    end
  end

end
