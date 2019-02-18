require_relative '../../spec_helper'

describe Enumerable do

  describe :split do
    context "by object" do
      it "must split at matching element" do
        [1, 2, 0, 3, 4].split(0).must_equal [[1, 2], [3, 4]]
      end

      it "won't split when no element matches" do
        [1, 2, 3].split(0).must_equal [[1, 2, 3]]
      end

      it "won't split zero length enumerable" do
        [].split(0).must_equal []
      end

      it "must keep leading empty subarrays" do
        [0, 1, 2, 0, 3, 4].split(0).must_equal [[], [1, 2], [3, 4]]
      end

      it "must keep empty subarrays in the middle" do
        [1, 2, 0, 0, 3, 4].split(0).must_equal [[1, 2], [], [3, 4]]
      end

      it "must drop trailing empty subarrays" do
        [1, 2, 0, 3, 4, 0].split(0).must_equal [[1, 2], [3, 4]]
      end
    end

    context "by block" do
      it "must split at matching element" do
        [1, 2, 0, 3, 4].split { |e| e.zero? }.must_equal [[1, 2], [3, 4]]
      end

      it "won't split when no element matches" do
        [1, 2, 3].split { |e| e.zero? }.must_equal [[1, 2, 3]]
      end

      it "won't split zero length enumerable" do
        [].split { |e| e.zero? }.must_equal []
      end

      it "must keep leading empty subarrays" do
        [0, 1, 2, 0, 3, 4].split { |e| e.zero? }.must_equal [[], [1, 2], [3, 4]]
      end

      it "must keep empty subarrays in the middle" do
        [1, 2, 0, 0, 3, 4].split { |e| e.zero? }.must_equal [[1, 2], [], [3, 4]]
      end

      it "must drop trailing empty subarrays" do
        [1, 2, 0, 3, 4, 0].split { |e| e.zero? }.must_equal [[1, 2], [3, 4]]
      end
    end
  end

  describe :group_by_chunks do
    it "fails to group if the first element does not meet the chunk condition" do
      subject = [10, 11, 12, 2, 20, 21 ]
      -> { subject.group_by_chunks { |i| i < 10 } }.must_raise ArgumentError
    end

    it "must map matching elements to array of subsequent non-matching elements" do
      subject = [1, 10, 11, 12, 2, 20, 21, 3, 30, 31, 32]
      subject.group_by_chunks { |i| i < 10 }.must_equal(1 => [10, 11, 12], 2 => [20, 21], 3 => [30, 31, 32])
    end

    it "must map matching elements to empty array if no subsequent non-matching elements exist" do
      subject = [1, 10, 11, 12, 2, 3, 30]
      subject.group_by_chunks { |i| i < 10 }.must_equal(1 => [10, 11, 12], 2 => [], 3 => [30])
    end
  end

end
