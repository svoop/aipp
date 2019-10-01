require_relative '../../spec_helper'

describe Integer do

  describe :up_or_downto do
    it "behaves like Integer#upto for an increasing range" do
      _(10.up_or_downto(12).to_a).must_equal 10.upto(12).to_a
    end

    it "behaves like Integer#downto for a decreasing range" do
      _(10.up_or_downto(8).to_a).must_equal 10.downto(8).to_a
    end
  end

end
