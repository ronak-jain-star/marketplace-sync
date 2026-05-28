require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

require "rspec/rails"
require "factory_bot_rails"
require "test_prof/recipes/rspec/before_all"
require "webmock/rspec"

silence_warnings do
  RedisPool = ConnectionPool.new(size: 5) do
    Redis.new(
      url: ENV.fetch("REDIS_TEST_URL", "redis://localhost:6379/15"),
      timeout: 5
    )
  end
end

WebMock.disable_net_connect!(allow_localhost: true)

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods

  # Flush Redis between examples. before_all is for DB factory data;
  # Redis side-effects belong in before(:each) or the example body.
  config.before(:each) do
    RedisPool.with { |r| r.flushdb }
  end
end
