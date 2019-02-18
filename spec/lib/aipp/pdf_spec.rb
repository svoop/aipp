require_relative '../../spec_helper'

describe AIPP::PDF do
  let :fixtures_dir do
    Pathname(__FILE__).join('..', '..', '..', 'fixtures')
  end

  subject do
    AIPP::PDF.new(fixtures_dir.join('document.pdf'))
  end

  describe :@page_ranges do
    it "returns an array of page end positions" do
      subject.instance_variable_get(:@page_ranges).must_equal [74, 149, 225]
    end
  end

  describe :page_for do
    it "finds the page for any given position" do
      subject.send(:page_for, index: 0).must_equal 1
      subject.send(:page_for, index: 50).must_equal 1
      subject.send(:page_for, index: 74).must_equal 1
      subject.send(:page_for, index: 75).must_equal 2
      subject.send(:page_for, index: 149).must_equal 2
      subject.send(:page_for, index: 150).must_equal 3
      subject.send(:page_for, index: 223).must_equal 3
    end
  end

  describe :from do
    it "fences beginning to any position" do
      subject.from(100).range.must_equal (100..223)
    end

    it "fences beginning to first existing position" do
      subject.from(:begin).range.must_equal (0..223)
    end
  end

  describe :to do
    it "fences beginning to any position" do
      subject.to(100).range.must_equal (0..100)
    end

    it "fences beginning to first existing position" do
      subject.to(:end).range.must_equal (0..223)
    end
  end

  context "without boundaries" do
    describe :text do
      it "returns the entire text" do
        subject.text.must_match /\Apage 1, line 1/
        subject.text.must_match /page 3, line 5\z/
      end
    end

    describe :each_line do
      it "maps lines to positions" do
        target = [
          ["page 1, line 1\n", 1, false],
          ["page 1, line 2\n", 1, false],
          ["page 1, line 3\n", 1, false],
          ["page 1, line 4\n", 1, false],
          ["page 1, line 5\f", 1, false],
          ["page 2, line 1\n", 2, false],
          ["page 2, line 2\n", 2, false],
          ["page 2, line 3\n", 2, false],
          ["page 2, line 4\n", 2, false],
          ["page 2, line 5\f", 2, false],
          ["page 3, line 1\n", 3, false],
          ["page 3, line 2\n", 3, false],
          ["page 3, line 3\n", 3, false],
          ["page 3, line 4\n", 3, false],
          ["page 3, line 5", 3, true]
        ]
        subject.each_line do |line, page, last|
          target_line, target_page, target_last = target.shift
          line.must_equal target_line
          page.must_equal target_page
          last.must_equal target_last
        end
      end

      it "returns an enumerator if no block is given" do
        subject.each_line.must_be_instance_of Enumerator
      end
    end
  end

  context "with boundaries" do
    before do
      subject.from(100).to(200)
    end

    describe :text do
      it "returns the entire text" do
        subject.text.must_match /\Ane 2/
        subject.text.must_match /page 3\z/
      end
    end

    describe :each_line do
      it "maps lines to positions" do
        target = [
          ["ne 2\n", 2, false],
          ["page 2, line 3\n", 2, false],
          ["page 2, line 4\n", 2, false],
          ["page 2, line 5\f", 2, false],
          ["page 3, line 1\n", 3, false],
          ["page 3, line 2\n", 3, false],
          ["page 3, line 3\n", 3, false],
          ["page 3", 3, true]
        ]
        subject.each_line do |line, page, last|
          target_line, target_page, target_last = target.shift
          line.must_equal target_line
          page.must_equal target_page
          last.must_equal target_last
        end
      end
    end
  end
end
