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

end
