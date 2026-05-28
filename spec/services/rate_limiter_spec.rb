require "rails_helper"

RSpec.describe RateLimiter do
  describe "#take" do
    context "when burst capacity is available" do
      before_all do
        @limiter = described_class.new(
          channel: "amazon", seller_id: "seller-A",
          rate_per_sec: 5.0, burst: 3
        )
      end

      it "allows up to burst tokens immediately" do
        results = Array.new(3) { @limiter.take }
        expect(results).to all(eq(true))
      end

      it "rejects when burst is exhausted" do
        Array.new(3) { @limiter.take }
        expect(@limiter.take).to eq(false)
      end
    end

    context "when buckets are scoped per (channel, seller)" do
      before_all do
        @a = described_class.new(channel: "amazon",  seller_id: "seller-A", rate_per_sec: 1, burst: 1)
        @b = described_class.new(channel: "walmart", seller_id: "seller-A", rate_per_sec: 1, burst: 1)
        @c = described_class.new(channel: "amazon",  seller_id: "seller-B", rate_per_sec: 1, burst: 1)
      end

      it "does not share tokens across channels or sellers" do
        expect(@a.take).to eq(true)
        expect(@b.take).to eq(true)
        expect(@c.take).to eq(true)
        expect(@a.take).to eq(false)
      end
    end
  end
end
