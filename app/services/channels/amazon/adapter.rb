require "httparty"

module Channels
  module Amazon
    class Adapter
      ENDPOINT = ENV.fetch("AMAZON_FAKE_URL", "http://localhost:4001")

      def name; "amazon"; end
      def rate_per_sec; 6.0; end
      def burst; 12; end

      def push(payload, version:, idempotency_key:)
        body = {
          asin: payload["sku"],
          title: payload["title"],
          price: payload["price_cents"].to_i / 100.0,
          qty: payload["inventory_qty"]
        }
        res = HTTParty.post(
          "#{ENDPOINT}/listings",
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
        else { error: "amazon http #{res.code}: #{res.body}" }
        end
      rescue => e
        { error: "amazon exception: #{e.class}: #{e.message}" }
      end
    end
  end
end
