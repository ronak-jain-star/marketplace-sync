class Listing < ApplicationRecord
  CHANNELS = %w[amazon walmart].freeze

  has_many :channel_listings, foreign_key: :sku, primary_key: :sku, dependent: :destroy
  has_many :listing_events,    foreign_key: :sku, primary_key: :sku, dependent: :destroy

  validates :sku, :seller_id, :title, presence: true
  validates :sku, uniqueness: true
end
