FactoryBot.define do
  factory :listing do
    sequence(:sku) { |n| "SKU-#{n}" }
    seller_id     { "seller-A" }
    title         { "Wireless Earbuds" }
    description   { "Bluetooth 5.3 earbuds with ANC" }
    brand         { "Acme" }
    category      { "Electronics" }
    price_cents   { 4999 }
    currency      { "USD" }
    inventory_qty { 100 }
    attributes_data { {} }
    version       { 1 }
  end

  factory :channel_listing do
    association :listing
    sku             { listing.sku }
    channel         { "amazon" }
    desired_version { 1 }
    applied_version { 0 }
    status          { "pending" }
    retry_count     { 0 }
  end

  factory :listing_event do
    sku        { "SKU-1" }
    channel    { "amazon" }
    version    { 1 }
    payload    { { "sku" => sku, "title" => "x" } }
    created_at { Time.current }
  end
end
