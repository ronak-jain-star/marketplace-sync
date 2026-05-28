require "rails_helper"

RSpec.describe Channels::Adapter do
  describe ".for" do
    it "returns the Amazon adapter" do
      expect(described_class.for("amazon")).to be_a(Channels::Amazon::Adapter)
    end

    it "returns the Walmart adapter" do
      expect(described_class.for("walmart")).to be_a(Channels::Walmart::Adapter)
    end

    it "raises for unknown channels" do
      expect { described_class.for("ebay") }.to raise_error(/Unknown channel/)
    end
  end
end

RSpec.describe Channels::Amazon::Adapter do
  let(:adapter) { described_class.new }
  let(:payload) do
    {
      "sku" => "SKU-1", "title" => "Earbuds",
      "price_cents" => 4999, "inventory_qty" => 10
    }
  end

  it "exposes channel metadata" do
    expect(adapter.name).to eq("amazon")
    expect(adapter.rate_per_sec).to be > 0
    expect(adapter.burst).to be > 0
  end

  context "when the marketplace accepts" do
    before do
      stub_request(:post, "#{described_class::ENDPOINT}/listings")
        .to_return(status: 200, body: "{}")
    end

    it "returns :ok" do
      expect(adapter.push(payload, version: 1, idempotency_key: "SKU-1:amazon:1")).to eq(:ok)
    end

    it "sends the Idempotency-Key header" do
      adapter.push(payload, version: 1, idempotency_key: "SKU-1:amazon:1")
      expect(WebMock).to have_requested(:post, "#{described_class::ENDPOINT}/listings")
        .with(headers: { "Idempotency-Key" => "SKU-1:amazon:1", "X-Version" => "1" })
    end
  end

  context "when the marketplace returns 429" do
    before do
      stub_request(:post, "#{described_class::ENDPOINT}/listings").to_return(status: 429, body: "{}")
    end

    it "returns :rate_limited" do
      expect(adapter.push(payload, version: 1, idempotency_key: "k")).to eq(:rate_limited)
    end
  end

  context "when the marketplace returns 5xx" do
    before do
      stub_request(:post, "#{described_class::ENDPOINT}/listings").to_return(status: 503, body: "boom")
    end

    it "returns an error hash" do
      result = adapter.push(payload, version: 1, idempotency_key: "k")
      expect(result).to be_a(Hash)
      expect(result[:error]).to match(/503/)
    end
  end
end
