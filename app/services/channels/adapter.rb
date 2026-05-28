module Channels
  # Adapter interface. Implementations live in app/services/channels/<name>/adapter.rb
  # and respond to:
  #   - name              => String (channel key, matches DB rows)
  #   - rate_per_sec      => Float
  #   - burst             => Integer
  #   - push(listing_payload, version:, idempotency_key:) => :ok | :rate_limited | { error: ... }
  class Adapter
    def self.for(channel)
      case channel.to_s
      when "amazon"  then Channels::Amazon::Adapter.new
      when "walmart" then Channels::Walmart::Adapter.new
      else raise "Unknown channel: #{channel}"
      end
    end
  end
end
