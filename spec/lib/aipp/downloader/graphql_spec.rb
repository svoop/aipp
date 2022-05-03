require_relative '../../../spec_helper'

describe AIPP::Downloader::GraphQL do
  subject do
    AIPP::Downloader::GraphQL
  end

  describe :name do
    it "returns the digest of client and query" do
      _(subject.new(client: 0, query: 0, variables: 0).send(:name)).must_equal '03643c5b'
      _(subject.new(client: 0, query: 0, variables: 1).send(:name)).must_equal '037fe0aa'
      _(subject.new(client: 0, query: 1, variables: 0).send(:name)).must_equal '562e71ee'
      _(subject.new(client: 0, query: 1, variables: 1).send(:name)).must_equal '9b3d7521'
      _(subject.new(client: 1, query: 0, variables: 0).send(:name)).must_equal 'e4873aab'
      _(subject.new(client: 1, query: 0, variables: 1).send(:name)).must_equal 'a56b3009'
      _(subject.new(client: 1, query: 1, variables: 0).send(:name)).must_equal 'a5eaf240'
      _(subject.new(client: 1, query: 1, variables: 1).send(:name)).must_equal '2ea5b261'
    end
  end

  describe :type do
    it "returns always JSON" do
      _(subject.new(client: 0, query: 0, variables: 0).send(:type)).must_equal :json
    end
  end
end
