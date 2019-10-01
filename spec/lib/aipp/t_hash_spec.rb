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
        _(subject.tsort).must_equal %i(net dns logger webserver)
      end

      it "must compile partial dependency lists" do
        _(subject.tsort(:dns)).must_equal %i(net dns)
        _(subject.tsort(:logger)).must_equal %i(logger)
        _(subject.tsort(:webserver)).must_equal %i(net dns logger webserver)
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
        _{ subject.tsort }.must_raise TSort::Cyclic
        _{ subject.tsort(:dns) }.must_raise TSort::Cyclic
      end
    end
  end
end
