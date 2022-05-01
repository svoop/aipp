require_relative '../../spec_helper'

describe Nokogiri do
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
    Nokogiri.XML(xml, &:noblanks).at_css('record')
  end

  describe Nokogiri::PseudoClasses::Matches do
    describe ':matches()' do
      it "must find nodes with matching content" do
        _(subject.at('location:matches("^b.r")', Nokogiri::MATCHES)).must_equal subject.at('/xml/record/location')
      end

      it "finds nothing if no content matches" do
        _(subject.at('location:matches("^x")', Nokogiri::MATCHES)).must_be :nil?
      end
    end
  end

  describe Nokogiri::XML::Element do
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

    describe :contents do
      it "must convert child elements to hash" do
        _(subject.contents).must_equal({ name: 'foo', location: 'bar', boolean: 'Yes' })
      end
    end

    describe :find_or_add_child do
      it "returns an existing child" do
        _(subject.find_or_add_child('location', after_css: []).to_s).must_equal '<location>bar</location>'
      end

      context "after_css is given" do
        it "returns nil if child is not existing and no add position can be determined" do
          _(subject.find_or_add_child('missing', after_css: [])).must_be :nil?
        end

        it "adds a new child element after the last matching position and before_css is ignored" do
          added = subject.find_or_add_child('new', after_css: ['name', 'location', 'missing'], before_css: ['location'])
          _(added.to_s).must_equal '<new/>'
          _(added).must_be_instance_of Nokogiri::XML::Element
          _(subject.to_xml(indent: 2)).must_equal <<~END.strip
            <record>
              <name>foo</name>
              <location>bar</location>
              <new/>
              <boolean>Yes</boolean>
            </record>
          END
        end
      end

      context "only before_css is given" do
        it "returns nil if child is not existing and no add position can be determined" do
          _(subject.find_or_add_child('missing', before_css: [])).must_be :nil?
        end

        it "adds a new child element before the first matching position" do
          added = subject.find_or_add_child('new', before_css: ['missing', 'location', 'boolean'])
          _(added.to_s).must_equal '<new/>'
          _(added).must_be_instance_of Nokogiri::XML::Element
          _(subject.to_xml(indent: 2)).must_equal <<~END.strip
            <record>
              <name>foo</name>
              <new/>
              <location>bar</location>
              <boolean>Yes</boolean>
            </record>
          END
        end
      end

      context "neither after_css nor before_css are given" do
        it "adds a new child at last position" do
          added = subject.find_or_add_child('new')
          _(added.to_s).must_equal '<new/>'
          _(added).must_be_instance_of Nokogiri::XML::Element
          _(subject.to_xml(indent: 2)).must_equal <<~END.strip
            <record>
              <name>foo</name>
              <location>bar</location>
              <boolean>Yes</boolean>
              <new/>
            </record>
          END
        end
      end
    end

  end
end
