class ChannelListing < ApplicationRecord
  STATUSES = %w[pending in_flight live rejected error].freeze

  belongs_to :listing, foreign_key: :sku, primary_key: :sku
  validates :sku, :channel, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
end
