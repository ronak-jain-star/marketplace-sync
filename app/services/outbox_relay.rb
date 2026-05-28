# Reads unpublished outbox rows and pushes them to Redis Streams.
# Idempotent: only marks published_at after XADD succeeds.
# Single-writer per partition guaranteed by SKIP LOCKED.
class OutboxRelay
  STREAM_PREFIX = "listing.events"
  BATCH = 100

  def self.run(loop_forever: true, sleep_sec: 0.5)
    loop do
      processed = new.tick
      break unless loop_forever
      sleep(sleep_sec) if processed.zero?
    end
  end

  def tick
    rows = ListingEvent.connection.select_all(<<~SQL).to_a
      SELECT id, sku, channel, version, payload
      FROM listing_events
      WHERE published_at IS NULL
      ORDER BY id
      FOR UPDATE SKIP LOCKED
      LIMIT #{BATCH}
    SQL

    return 0 if rows.empty?

    ids = []
    RedisPool.with do |r|
      rows.each do |row|
        r.call(
          "XADD",
          "#{STREAM_PREFIX}.#{row['channel']}",
          "*",
          "sku", row["sku"],
          "version", row["version"].to_s,
          "payload", row["payload"].to_json,
          "event_id", row["id"].to_s
        )
        ids << row["id"]
      end
    end

    ListingEvent.where(id: ids).update_all(published_at: Time.current)
    ids.size
  end
end
