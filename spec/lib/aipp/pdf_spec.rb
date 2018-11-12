require_relative '../../spec_helper'

describe AIPP::PDF do
  let :fixtures_dir do
    Pathname(__FILE__).join('..', '..', '..', 'fixtures')
  end

  subject do
    AIPP::PDF.new(fixtures_dir.join('document.pdf'))
  end

  describe :page_ranges do
    it "returns an array of page end positions" do
      subject.send(:page_ranges).must_equal [74, 149, 225]
    end
  end

  describe :page_for do
    it "finds the page for any given position" do
      subject.send(:page_for, position: 0).must_equal 1
      subject.send(:page_for, position: 50).must_equal 1
      subject.send(:page_for, position: 74).must_equal 1
      subject.send(:page_for, position: 75).must_equal 2
      subject.send(:page_for, position: 149).must_equal 2
      subject.send(:page_for, position: 150).must_equal 3
      subject.send(:page_for, position: 224).must_equal 3
    end
  end

  describe :from do
    it "fences beginning to any position" do
      subject.from(100).range.must_equal (100..224)
    end

    it "fences beginning to first existing position" do
      subject.from(:begin).range.must_equal (0..224)
    end
  end

  describe :to do
    it "fences beginning to any position" do
      subject.to(100).range.must_equal (0..100)
    end

    it "fences beginning to first existing position" do
      subject.to(:end).range.must_equal (0..224)
    end
  end

  context "without boundaries" do
    describe :each_line_with_page do
      it "returns an Enumerator" do
        subject.each_line_with_page.must_be_instance_of Enumerator
      end

      it "maps lines with stripped line separator to page" do
        subject.each_line_with_page.to_a.must_equal [
          ["page 1, line 1\n", 1],
          ["page 1, line 2\n", 1],
          ["page 1, line 3\n", 1],
          ["page 1, line 4\n", 1],
          ["page 1, line 5\f", 1],
          ["page 2, line 1\n", 2],
          ["page 2, line 2\n", 2],
          ["page 2, line 3\n", 2],
          ["page 2, line 4\n", 2],
          ["page 2, line 5\f", 2],
          ["page 3, line 1\n", 3],
          ["page 3, line 2\n", 3],
          ["page 3, line 3\n", 3],
          ["page 3, line 4\n", 3],
          ["page 3, line 5", 3]
        ]
      end
    end
  end

  context "with boundaries" do
    it "maps lines with stripped line separator to page" do
      subject.from(100).to(200).each_line_with_page.to_a.must_equal [
        ["ne 2\n", 2],
        ["page 2, line 3\n", 2],
        ["page 2, line 4\n", 2],
        ["page 2, line 5\f", 2],
        ["page 3, line 1\n", 3],
        ["page 3, line 2\n", 3],
        ["page 3, line 3\n", 3],
        ["page 3", 3]
      ]
    end
  end
end
