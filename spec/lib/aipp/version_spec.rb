require_relative '../../spec_helper'

describe AIPP do
  it "must be defined" do
    _(AIPP::VERSION).wont_be_nil
  end
end
