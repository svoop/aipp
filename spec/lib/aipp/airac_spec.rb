require_relative '../../spec_helper'

describe AIPP::AIRAC do
  describe :initialize do
    it "won't accept invalid arguments" do
      -> { AIPP::AIRAC.new(0) }.must_raise ArgumentError
      -> { AIPP::AIRAC.new(AIPP::AIRAC::ROOT_DATE - 1) }.must_raise ArgumentError
    end
  end

  context "on AIRAC date (as Date)" do
    subject do
      AIPP::AIRAC.new(Date.parse('2018-01-04'))
    end

    it "must calculate correct #date" do
      subject.date.must_equal Date.parse('2018-01-04')
    end

    it "must calculate correct #id" do
      subject.id.must_equal 1801
    end

    it "must calculate correct #next_date" do
      subject.next_date.must_equal Date.parse('2018-02-01')
    end

    it "must calculate correct #next_id" do
      subject.next_id.must_equal 1802
    end
  end

  context "one day before AIRAC date (as String)" do
    subject do
      AIPP::AIRAC.new('2018-01-03')
    end

    it "must calculate correct #date" do
      subject.date.must_equal Date.parse('2017-12-07')
    end

    it "must calculate correct #id" do
      subject.id.must_equal 1713
    end

    it "must calculate correct #next_date" do
      subject.next_date.must_equal Date.parse('2018-01-04')
    end

    it "must calculate correct #next_id" do
      subject.next_id.must_equal 1801
    end
  end

  context "one day after AIRAC date" do
    subject do
      AIPP::AIRAC.new(Date.parse('2018-01-05'))
    end

    it "must calculate correct #date" do
      subject.date.must_equal Date.parse('2018-01-04')
    end

    it "must calculate correct #id" do
      subject.id.must_equal 1801
    end

    it "must calculate correct #next_date" do
      subject.next_date.must_equal Date.parse('2018-02-01')
    end

    it "must calculate correct #next_id" do
      subject.next_id.must_equal 1802
    end
  end

  context "end of year with 14 AIRAC cycles" do
    subject do
      AIPP::AIRAC.new(Date.parse('2020-12-31'))
    end

    it "must calculate correct #date" do
      subject.date.must_equal Date.parse('2020-12-31')
    end

    it "must calculate correct #id" do
      subject.id.must_equal 2014
    end

    it "must calculate correct #next_date" do
      subject.next_date.must_equal Date.parse('2021-01-28')
    end

    it "must calculate correct #next_id" do
      subject.next_id.must_equal 2101
    end
  end
end
