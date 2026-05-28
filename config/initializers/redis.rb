require "connection_pool"
require "redis"

REDIS_URL = ENV.fetch("REDIS_URL", "redis://localhost:6379/2")

RedisPool = ConnectionPool.new(size: 10, timeout: 5) do
  Redis.new(url: REDIS_URL)
end
