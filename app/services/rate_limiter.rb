# Token bucket per (channel, seller). Refills lazily on each take.
# Returns true if the token was acquired, false if rate-limited.
class RateLimiter
  def initialize(channel:, seller_id:, rate_per_sec:, burst:)
    @key = "rl:#{channel}:#{seller_id}"
    @rate = rate_per_sec.to_f
    @burst = burst.to_i
  end

  # Refill formula: tokens = min(burst, prev + (now - last) * rate)
  LUA = <<~LUA.freeze
    local key   = KEYS[1]
    local now   = tonumber(ARGV[1])
    local rate  = tonumber(ARGV[2])
    local burst = tonumber(ARGV[3])
    local data  = redis.call("HMGET", key, "tokens", "ts")
    local tokens = tonumber(data[1]) or burst
    local ts     = tonumber(data[2]) or now
    local delta  = math.max(0, now - ts)
    tokens = math.min(burst, tokens + delta * rate)
    local allowed = 0
    if tokens >= 1 then
      tokens = tokens - 1
      allowed = 1
    end
    redis.call("HMSET", key, "tokens", tokens, "ts", now)
    redis.call("EXPIRE", key, 3600)
    return allowed
  LUA

  def take
    RedisPool.with do |r|
      r.call("EVAL", LUA, 1, @key, Time.now.to_f.to_s, @rate.to_s, @burst.to_s).to_i == 1
    end
  end
end
