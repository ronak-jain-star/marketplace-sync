require "rails_helper"

RSpec.describe Listings::Upsert do
  describe "#call" do
    context "when creating a new listing" do
      before_all do
        @result = described_class.new(
          sku: "SKU-NEW",
          attrs: {
            seller_id: "seller-A",
            title: "Earbuds Pro",
            price_cents: 4999,
            inventory_qty: 100
          }
        ).call
      end

      it "creates the listing at version 1" do
        expect(@result.sku).to eq("SKU-NEW")
        expect(@result.version).to eq(1)
      end

      it "creates one channel_listing per channel at status pending" do
        rows = ChannelListing.where(sku: "SKU-NEW").order(:channel)
        expect(rows.map(&:channel)).to eq(%w[amazon walmart])
        expect(rows.map(&:status).uniq).to eq([ "pending" ])
        expect(rows.map(&:desired_version).uniq).to eq([ 1 ])
      end

      it "writes one outbox event per channel atomically" do
        events = ListingEvent.where(sku: "SKU-NEW").order(:channel)
        expect(events.count).to eq(2)
        expect(events.pluck(:version).uniq).to eq([ 1 ])
        expect(events.pluck(:published_at).uniq).to eq([ nil ])
      end
    end

    context "when updating an existing listing" do
      before_all do
        described_class.new(
          sku: "SKU-UPD",
          attrs: { seller_id: "seller-A", title: "v1", price_cents: 1000 }
        ).call

        @result = described_class.new(
          sku: "SKU-UPD",
          attrs: { seller_id: "seller-A", title: "v2", price_cents: 2000 }
        ).call
      end

      it "increments version" do
        expect(@result.version).to eq(2)
      end

      it "updates desired_version on channel rows and resets status to pending" do
        rows = ChannelListing.where(sku: "SKU-UPD")
        expect(rows.map(&:desired_version).uniq).to eq([ 2 ])
        expect(rows.map(&:status).uniq).to eq([ "pending" ])
      end

      it "emits a new outbox event per channel for the new version" do
        events = ListingEvent.where(sku: "SKU-UPD", version: 2)
        expect(events.count).to eq(2)
      end
    end

    context "when channels argument is restricted" do
      before_all do
        @result = described_class.new(
          sku: "SKU-ONE",
          attrs: { seller_id: "seller-A", title: "x", price_cents: 1 },
          channels: [ "amazon" ]
        ).call
      end

      it "emits only events for requested channels" do
        expect(ListingEvent.where(sku: "SKU-ONE").pluck(:channel)).to eq([ "amazon" ])
        expect(ChannelListing.where(sku: "SKU-ONE").pluck(:channel)).to eq([ "amazon" ])
      end
    end
  end
end
