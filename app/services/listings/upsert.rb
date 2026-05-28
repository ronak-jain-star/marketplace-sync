# Writes a listing + per-channel outbox events atomically.
# This is the Transactional Outbox pattern: catalog change + event emission
# share a single DB transaction, so we never lose or duplicate events at source.
class Listings::Upsert
  def initialize(sku:, attrs:, channels: Listing::CHANNELS)
    @sku = sku
    @attrs = attrs
    @channels = channels
  end

  def call
    Listing.transaction do
      listing = Listing.lock.find_or_initialize_by(sku: @sku)
      listing.assign_attributes(@attrs)
      listing.version = listing.version.to_i + 1 if listing.persisted?
      listing.save!

      @channels.each do |channel|
        ListingEvent.create!(
          sku: listing.sku,
          channel: channel,
          version: listing.version,
          payload: listing.as_json,
          created_at: Time.current
        )
        ChannelListing
          .find_or_initialize_by(sku: listing.sku, channel: channel)
          .tap do |cl|
            cl.desired_version = listing.version
            cl.status = "pending" if cl.status == "live" || cl.new_record?
            cl.save!
          end
      end

      listing
    end
  end
end
