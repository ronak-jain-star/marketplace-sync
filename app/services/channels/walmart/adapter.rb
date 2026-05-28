require "httparty"

module Channels
  module Walmart
    class Adapter
      ENDPOINT = ENV.fetch("WALMART_FAKE_URL", "http://localhost:4002")

      def name; "walmart"; end
      def rate_per_sec; 4.0; end
      def burst; 8; end

      def push(payload, version:, idempotency_key:)
        body = {
          itemId: payload["sku"],
          name: payload["title"],
          priceCents: payload["price_cents"],
          stock: payload["inventory_qty"]
        }
        res = HTTParty.post(
          "#{ENDPOINT}/items",
          body: body.to_json,
          headers: {
            "Content-Type" => "application/json",
            "Idempotency-Key" => idempotency_key,
            "X-Version" => version.to_s
          },
          timeout: 5
        )
        case res.code
        when 200, 201 then :ok
        when 429      then :rate_limited
        else { error: "walmart http #{res.code}: #{res.body}" }
        end
      rescue => e
        { error: "walmart exception: #{e.class}: #{e.message}" }
      end
    end
  end
end
