source "https://rubygems.org"

gem "rails", "~> 8.0.5"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

gem "blueprinter"
gem "sidekiq"
gem "redis"
gem "connection_pool"
gem "rack-cors", require: "rack/cors"
gem "httparty"

gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails"
  gem "faker"
  gem "webmock"
  gem "simplecov", require: false
end

group :development do
  gem "foreman"
  gem "sinatra"
  gem "rackup"
end
