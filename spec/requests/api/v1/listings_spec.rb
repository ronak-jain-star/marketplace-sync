require "rails_helper"

RSpec.describe "POST /api/v1/listings", type: :request do
  context "when creating a new listing" do
    before_all do
      post "/api/v1/listings",
           params: {
             sku: "SKU-API-1",
             seller_id: "seller-A",
             title: "Earbuds",
             price_cents: 4999,
             inventory_qty: 100
           }
      @body = JSON.parse(response.body)
    end

    it "returns 201" do
      expect(response).to have_http_status(:created)
    end

    it "returns the listing with both channels in pending state" do
      expect(@body["sku"]).to eq("SKU-API-1")
      expect(@body["version"]).to eq(1)
      expect(@body["channels"].map { |c| c["channel"] }.sort).to eq(%w[amazon walmart])
      expect(@body["channels"].map { |c| c["status"] }.uniq).to eq([ "pending" ])
    end
  end
end

RSpec.describe "PUT /api/v1/listings/:id", type: :request do
  before_all do
    Listings::Upsert.new(
      sku: "SKU-API-2",
      attrs: { seller_id: "seller-A", title: "v1", price_cents: 1000 }
    ).call

    put "/api/v1/listings/SKU-API-2",
        params: { seller_id: "seller-A", title: "v2", price_cents: 2000 }
    @body = JSON.parse(response.body)
  end

  it "returns 200 with incremented version" do
    expect(response).to have_http_status(:ok)
    expect(@body["version"]).to eq(2)
  end

  it "resets channels to pending at desired_version 2" do
    expect(@body["channels"].map { |c| c["desired_version"] }.uniq).to eq([ 2 ])
    expect(@body["channels"].map { |c| c["status"] }.uniq).to eq([ "pending" ])
  end
end

RSpec.describe "GET /api/v1/listings/:id", type: :request do
  before_all do
    Listings::Upsert.new(
      sku: "SKU-API-3",
      attrs: { seller_id: "seller-A", title: "x", price_cents: 100 }
    ).call
    get "/api/v1/listings/SKU-API-3"
    @body = JSON.parse(response.body)
  end

  it "returns 200" do
    expect(response).to have_http_status(:ok)
  end

  it "exposes per-channel sync state" do
    expect(@body["sku"]).to eq("SKU-API-3")
    expect(@body["channels"].size).to eq(2)
    expect(@body["channels"].first.keys).to include(
      "channel", "status", "desired_version", "applied_version",
      "last_error", "last_synced_at", "retry_count"
    )
  end
end
