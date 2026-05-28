require "rails_helper"

RSpec.describe OutboxRelay do
  describe "#tick" do
    context "with no unpublished events" do
      it "returns 0" do
        expect(described_class.new.tick).to eq(0)
      end
    end

    context "with unpublished events" do
      before_all do
        Listings::Upsert.new(
          sku: "SKU-OB",
          attrs: { seller_id: "seller-A", title: "x", price_cents: 1 }
        ).call
      end

      before do
        @processed = described_class.new.tick
      end

      it "returns the number of rows processed" do
        expect(@processed).to eq(2)
      end

      it "marks the events as published" do
        expect(ListingEvent.where(sku: "SKU-OB").pluck(:published_at).compact.size).to eq(2)
      end

      it "writes one entry per channel stream in Redis" do
        amazon = RedisPool.with { |r| r.call("XLEN", "listing.events.amazon") }
        walmart = RedisPool.with { |r| r.call("XLEN", "listing.events.walmart") }
        expect(amazon).to eq(1)
        expect(walmart).to eq(1)
      end

      it "is idempotent on repeated ticks (no new stream entries)" do
        described_class.new.tick
        amazon_len = RedisPool.with { |r| r.call("XLEN", "listing.events.amazon") }
        expect(amazon_len).to eq(1)
      end
    end

    context "when an event row has already been published" do
      before_all do
        listing = Listings::Upsert.new(
          sku: "SKU-SKIP",
          attrs: { seller_id: "seller-A", title: "x", price_cents: 1 }
        ).call
        ListingEvent.where(sku: listing.sku).update_all(published_at: Time.current)
      end

      it "does not re-publish them" do
        expect(described_class.new.tick).to eq(0)
        len = RedisPool.with { |r| r.call("XLEN", "listing.events.amazon") }
        expect(len).to eq(0)
      end
    end
  end
end
