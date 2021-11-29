require_relative '../../spec_helper'

describe Nokogiri::XML::Element do

  subject do
    xml = <<~END
      <xml>
        <record>
          <name>foo</name>
          <location>bar</location>
          <boolean>Yes</boolean>
        </record>
      </xml>
    END
    Nokogiri.XML(xml).at_css('record')
  end

  describe :contents do
    it "must convert child elements to hash" do
      _(subject.contents).must_equal({ name: 'foo', location: 'bar', boolean: 'Yes' })
    end
  end

  describe :call do
    it "must return the value for an existing contents key" do
      _(subject.(:name)).must_equal 'foo'
    end

    it "must return nil for a non-existing contents key" do
      _(subject.(:not_found)).must_be :nil?
    end

    context "postfixed !" do
      it "must return the value for an existing contents key" do
        _(subject.(:name!)).must_equal 'foo'
      end

      it "must fail for a non-existing contents key" do
        _{ subject.(:not_found!) }.must_raise KeyError
      end
    end

    context "postfixed ?" do
      it "must return the boolean equivalent for an existing contents key" do
        _(subject.(:boolean?)).must_equal true
      end

      it "must fail for content without boolean equivalent" do
        _{ subject.(:name?) }.must_raise KeyError
      end

      it "must fail for a non-existing contents key" do
        _{ subject.(:not_found?) }.must_raise KeyError
      end
    end
  end

end
