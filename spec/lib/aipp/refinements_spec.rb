require_relative '../../spec_helper'

using AIPP::Refinements

describe AIPP::Refinements do

  context String do
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

    describe :blank? do
      it "all whitespace must return true" do
        "\n     \n         ".blank?.must_equal true
      end

      it "not all whitespace must return false" do
        "\nfoo bar\n".blank?.must_equal false
      end
    end

    describe :classify do
      it "must convert file name to class name" do
        "ENR-5.1".classify.must_equal "ENR51"
        "helper".classify.must_equal "Helper"
        "foo_bar".classify.must_equal "FooBar"
      end
    end
  end

  context NilClass do
    describe :blank_to_nil do
      it "must return self" do
        nil.blank_to_nil.must_be :nil?
      end
    end

    describe :blank? do
      it "must return true" do
        nil.blank?.must_equal true
      end
    end
  end

  context Array do
    describe :constantize do
      it "must convert to constant" do
        %w(AIPP Refinements).constantize.must_equal AIPP::Refinements
      end

      it "fails to convert to inexistant constant" do
        -> { %w(Foo Bar).constantize }.must_raise NameError
      end
    end
  end

  context Enumerable do
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
  end

end
