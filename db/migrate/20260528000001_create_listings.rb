class CreateListings < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :listings, id: :uuid do |t|
      t.string  :sku, null: false
      t.string  :seller_id, null: false
      t.string  :title, null: false
      t.text    :description
      t.string  :brand
      t.string  :category
      t.integer :price_cents, null: false, default: 0
      t.string  :currency, null: false, default: "USD"
      t.integer :inventory_qty, null: false, default: 0
      t.jsonb   :attributes_data, null: false, default: {}
      t.bigint  :version, null: false, default: 1
      t.timestamps
    end
    add_index :listings, :sku, unique: true
    add_index :listings, [ :seller_id, :updated_at ]

    create_table :channel_listings, id: :uuid do |t|
      t.string  :sku, null: false
      t.string  :channel, null: false
      t.string  :external_id
      t.bigint  :desired_version, null: false, default: 0
      t.bigint  :applied_version, null: false, default: 0
      t.string  :status, null: false, default: "pending"
      t.text    :last_error
      t.datetime :last_synced_at
      t.datetime :next_retry_at
      t.integer :retry_count, null: false, default: 0
      t.timestamps
    end
    add_index :channel_listings, [ :sku, :channel ], unique: true
    add_index :channel_listings, [ :channel, :status, :next_retry_at ]

    create_table :listing_events, id: :bigserial do |t|
      t.string  :sku, null: false
      t.string  :channel, null: false
      t.bigint  :version, null: false
      t.jsonb   :payload, null: false, default: {}
      t.datetime :created_at, null: false
      t.datetime :published_at
    end
    add_index :listing_events, :published_at
    add_index :listing_events, [ :sku, :channel, :version ], unique: true
  end
end
