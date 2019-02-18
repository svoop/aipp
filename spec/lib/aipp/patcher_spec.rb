require_relative '../../spec_helper'

class Shoe
  extend AIPP::Patcher

  attr_accessor :size

  patch Shoe, :size do |object, value|
    case value
      when 'S' then 36
      when 'one-size-fits-all' then nil
      else throw(:abort)
    end
  end
end

describe AIPP::Patcher do
  subject do
    Shoe.new
  end

  it "overwrites with non-nil values" do
    subject.tap { |s| s.size = 'S' }.size.must_equal 36
  end

  it "overwrite with nil values" do
    subject.tap { |s| s.size = 'one-size-fits-all' }.size.must_be_nil
  end

  it "skips overwrite if abort is thrown" do
    subject.tap { |s| s.size = 42 }.size.must_equal 42
  end

  it "removes patches" do
    subject.class.remove_patches
    subject.tap { |s| s.size = 'S' }.size.must_equal 'S'
  end
end
