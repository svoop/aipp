require_relative '../../spec_helper'

describe AIPP::THash do
  context "non-circular dependencies" do
    subject do
      AIPP::THash[
        dns: %i(net),
        webserver: %i(dns logger),
        net: [],
        logger: []
      ]
    end

    describe :tsort do
      it "must compile the overall dependency list" do
        subject.tsort.must_equal %i(net dns logger webserver)
      end

      it "must compile partial dependency lists" do
        subject.tsort(:dns).must_equal %i(net dns)
        subject.tsort(:logger).must_equal %i(logger)
        subject.tsort(:webserver).must_equal %i(net dns logger webserver)
      end
    end
  end

  context "circular dependencies" do
    subject do
      AIPP::THash[
        dns: %i(net),
        webserver: %i(dns logger),
        net: %i(dns),
        logger: []
      ]
    end

    describe :tsort do
      it "must raise cyclic dependency error" do
        -> { subject.tsort }.must_raise TSort::Cyclic
        -> { subject.tsort(:dns) }.must_raise TSort::Cyclic
      end
    end
  end
end
