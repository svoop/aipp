require_relative '../../spec_helper'

class Shoe
  include AIPP::Patcher

  attr_accessor :size

  patch Shoe, :size do |parser, object, value|
    case value
      when 'S' then 36
      when 'one-size-fits-all' then nil
      else throw(:abort)
    end
  end
end

describe AIPP::Patcher do
  subject do
    Shoe.new.attach_patches
  end

  context "with patches attached" do
    after do
      subject.detach_patches
    end

    it "overwrites with non-nil values" do
      _(subject.tap { _1.size = 'S' }.size).must_equal 36
    end

    it "overwrite with nil values" do
      _(subject.tap { _1.size = 'one-size-fits-all' }.size).must_be_nil
    end

    it "skips overwrite if abort is thrown" do
      _(subject.tap { _1.size = 42 }.size).must_equal 42
    end
  end

  context "with patches detached" do
    it "removes patches" do
      subject.detach_patches
      _(subject.tap { _1.size = 'S' }.size).must_equal 'S'
    end
  end
end
