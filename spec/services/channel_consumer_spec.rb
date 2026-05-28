require "rails_helper"

RSpec.describe ChannelConsumer do
  let(:channel) { "amazon" }
  let(:stream)  { "listing.events.amazon" }

  def xadd(payload)
    RedisPool.with do |r|
      r.call("XADD", stream, "*",
             "sku",     payload[:sku],
             "version", payload[:version].to_s,
             "payload", payload[:body].to_json,
             "event_id", "1")
    end
  end

  describe "#tick" do
    context "when the channel push succeeds" do
      before_all do
        @listing = create(:listing, sku: "SKU-OK")
        @cl = create(:channel_listing, listing: @listing, sku: "SKU-OK",
                                       channel: "amazon", desired_version: 1)
      end

      before do
        stub_request(:post, %r{/listings})
          .to_return(status: 200, body: "{}")
        consumer = described_class.new(channel: channel)
        xadd(sku: "SKU-OK", version: 1, body: @listing.as_json)
        consumer.tick
      end

      it "marks the channel_listing live with applied_version set" do
        @cl.reload
        expect(@cl.status).to eq("live")
        expect(@cl.applied_version).to eq(1)
        expect(@cl.last_synced_at).to be_present
      end

      it "acks the stream entry" do
        pending_count = RedisPool.with do |r|
          r.call("XPENDING", stream, described_class::GROUP)[0]
        end
        expect(pending_count).to eq(0)
      end
    end

    context "when the incoming version is older than applied_version" do
      before_all do
        @listing = create(:listing, sku: "SKU-OLD", version: 5)
        @cl = create(:channel_listing, listing: @listing, sku: "SKU-OLD",
                                       channel: "amazon",
                                       desired_version: 5, applied_version: 5,
                                       status: "live")
      end

      before do
        consumer = described_class.new(channel: channel)
        xadd(sku: "SKU-OLD", version: 3, body: @listing.as_json)
        consumer.tick
      end

      it "does not change channel_listing state" do
        @cl.reload
        expect(@cl.status).to eq("live")
        expect(@cl.applied_version).to eq(5)
      end

      it "does not call the marketplace" do
        expect(WebMock).not_to have_requested(:post, %r{/listings})
      end
    end

    context "when the marketplace returns a transient error" do
      before_all do
        @listing = create(:listing, sku: "SKU-ERR")
        @cl = create(:channel_listing, listing: @listing, sku: "SKU-ERR",
                                       channel: "amazon", desired_version: 1)
      end

      before do
        allow_any_instance_of(described_class).to receive(:sleep)
        stub_request(:post, %r{/listings}).to_return(status: 503, body: "boom")
        consumer = described_class.new(channel: channel)
        xadd(sku: "SKU-ERR", version: 1, body: @listing.as_json)
        consumer.tick
      end

      it "increments retry_count and re-queues for retry" do
        @cl.reload
        expect(@cl.retry_count).to eq(1)
        expect(@cl.status).to eq("pending")
        expect(@cl.last_error).to match(/503/)
        expect(@cl.next_retry_at).to be > Time.current
      end
    end

    context "when retries exceed MAX_RETRIES" do
      before_all do
        @listing = create(:listing, sku: "SKU-DEAD")
        @cl = create(:channel_listing, listing: @listing, sku: "SKU-DEAD",
                                       channel: "amazon", desired_version: 1,
                                       retry_count: described_class::MAX_RETRIES - 1)
      end

      before do
        allow_any_instance_of(described_class).to receive(:sleep)
        stub_request(:post, %r{/listings}).to_return(status: 500, body: "x")
        consumer = described_class.new(channel: channel)
        xadd(sku: "SKU-DEAD", version: 1, body: @listing.as_json)
        consumer.tick
      end

      it "moves the row to error status" do
        @cl.reload
        expect(@cl.status).to eq("error")
        expect(@cl.retry_count).to eq(described_class::MAX_RETRIES)
      end
    end
  end
end
