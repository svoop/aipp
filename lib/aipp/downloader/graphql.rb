module AIPP
  class Downloader

    # Remote file via HTTP
    class GraphQL < File
      def initialize(client:, query:, variables:)
        @client, @query, @variables = client, query, variables
      end

      def fetch_to(path)
        @client.query(@query, variables: @variables).tap do |result|
          ::File.write(path.join(fetched_file), result.data.to_h.to_json)
        end
        self
      end

      private

      def name
        [@client, @query, @variables].map(&:to_s).join('|').to_digest
      end

      def type
        :json
      end
    end

  end
end
