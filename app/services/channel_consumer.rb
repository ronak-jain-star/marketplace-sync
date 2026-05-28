# Reads from Redis Streams consumer group, calls the channel adapter,
# updates channel_listings, retries with backoff on failure.
class ChannelConsumer
  GROUP = "sync"
  CONSUMER = "consumer-1"
  MAX_RETRIES = 5

  def self.run(channel:)
    new(channel: channel).run
  end

  def initialize(channel:)
    @channel = channel
    @adapter = Channels::Adapter.for(channel)
    @stream  = "#{OutboxRelay::STREAM_PREFIX}.#{channel}"
    ensure_group
  end

  def run
    loop { tick }
  end

  def tick
    entries = RedisPool.with do |r|
      r.call("XREADGROUP", "GROUP", GROUP, CONSUMER, "COUNT", "10", "BLOCK", "2000", "STREAMS", @stream, ">")
    end
    return if entries.nil?

    entries[0][1].each do |entry_id, fields|
      h = Hash[fields.each_slice(2).to_a]
      process(entry_id, h)
    end
  end

  private

  def process(entry_id, h)
    sku     = h["sku"]
    version = h["version"].to_i
    payload = JSON.parse(h["payload"])
    seller  = payload["seller_id"]

    cl = ChannelListing.find_by(sku: sku, channel: @channel)
    return ack(entry_id) if cl.nil? || version <= cl.applied_version

    limiter = RateLimiter.new(channel: @channel, seller_id: seller,
                              rate_per_sec: @adapter.rate_per_sec, burst: @adapter.burst)
    unless limiter.take
      sleep(0.2)
      return # do not ack — will be redelivered
    end

    cl.update!(status: "in_flight", last_error: nil)
    idem = "#{sku}:#{@channel}:#{version}"
    result = @adapter.push(payload, version: version, idempotency_key: idem)

    case result
    when :ok
      cl.update!(status: "live", applied_version: version, last_synced_at: Time.current, retry_count: 0)
      ack(entry_id)
    when :rate_limited
      sleep(0.5) # backoff, don't ack
    else
      handle_error(cl, entry_id, result[:error])
    end
  end

  def handle_error(cl, entry_id, err)
    cl.retry_count += 1
    cl.last_error  = err
    if cl.retry_count >= MAX_RETRIES
      cl.status = "error"
      cl.save!
      ack(entry_id) # give up; surface in dashboard
    else
      delay = (2 ** cl.retry_count) + rand
      cl.status = "pending"
      cl.next_retry_at = Time.current + delay
      cl.save!
      sleep(delay)
    end
  end

  def ack(entry_id)
    RedisPool.with { |r| r.call("XACK", @stream, GROUP, entry_id) }
  end

  def ensure_group
    RedisPool.with do |r|
      begin
        r.call("XGROUP", "CREATE", @stream, GROUP, "$", "MKSTREAM")
      rescue Redis::CommandError => e
        raise unless e.message.include?("BUSYGROUP")
      end
    end
  end
end
