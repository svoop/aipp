require_relative '../../spec_helper'

describe NilClass do

  describe :blank_to_nil do
    it "must return nil" do
      _(nil.blank_to_nil).must_be :nil?
    end
  end

end
