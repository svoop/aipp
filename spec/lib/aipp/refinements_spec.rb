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

    describe :constantize do
      it "must convert to constant" do
        "AIPP::Refinements".constantize.must_equal AIPP::Refinements
        "AIPP::Re-fine.ments".constantize.must_equal AIPP::Refinements
      end

      it "fails to convert to inexistant constant" do
        -> { "Foo::Bar".constantize }.must_raise NameError
      end
    end
  end

  context NilClass do
    describe :blank_to_nil do
      it "must return self" do
        nil.blank_to_nil.must_be :nil?
      end
    end
  end

  context Array do
    describe :split do
      it "must split at pattern" do
        [1, 2, '---', 3, 4].split(/-+/).must_equal [[1, 2], [3, 4]]
      end

      it "won't split arrays with no pattern matches" do
        [1, 2, 3].split(/-+/).must_equal [[1, 2, 3]]
      end

      it "must keep leading empty subarrays" do
        ['---', 1, 2, '---', 3, 4].split(/-+/).must_equal [[], [1, 2], [3, 4]]
      end

      it "must keep empty subarrays in the middle" do
        [1, 2, '---', '---', 3, 4].split(/-+/).must_equal [[1, 2], [], [3, 4]]
      end

      it "must drop trailing empty subarrays" do
        [1, 2, '---', 3, 4, '---'].split(/-+/).must_equal [[1, 2], [3, 4]]
      end

      it "won't alter empty arrays" do
        [].split(/-+/).must_equal []
      end
    end
  end

end
