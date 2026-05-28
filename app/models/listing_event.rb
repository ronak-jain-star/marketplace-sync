class ListingEvent < ApplicationRecord
  scope :unpublished, -> { where(published_at: nil).order(:id) }
end
