require_relative '../../spec_helper'

describe AIPP::Callback do
  context "without callback" do
    class ShoeWithoutCallback
      attr_reader :size
      def size=(value)
        fail ArgumentError unless (30..50).include? value
        @size = value
      end
    end

    it "must fail for illegal arguments" do
      -> { ShoeWithoutCallback.new.size = 10 }.must_raise ArgumentError
    end
  end

  context "with callback" do
    class ShoeWithCallback
      attr_reader :size
      def size=(value)
        fail ArgumentError unless (30..50).include? value
        @size = value
      end
    end
    ShoeWithCallback.extend AIPP::Callback
    ShoeWithCallback.before :size= do |object, method, args|
      [42] if args.first < 30
    end

    it "must override illegal arguments with the callback return arguments" do
      ShoeWithCallback.new.tap { |s| s.size = 10 }.size.must_equal 42
    end

    it "it ignores the callback return arguments when nil" do
      ShoeWithCallback.new.tap { |s| s.size = 30 }.size.must_equal 30
      -> { ShoeWithCallback.new.size = 60 }.must_raise ArgumentError
    end
  end

end
