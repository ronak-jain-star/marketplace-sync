# Tiny Sinatra service that pretends to be Amazon SP-API.
# Honours Idempotency-Key (dedupes) and randomly 429s ~10% of the time.
require "sinatra"
require "json"
require "set"

set :port, ENV.fetch("PORT", 4001).to_i
set :bind, "0.0.0.0"

SEEN = Set.new
STORE = {}

post "/listings" do
  content_type :json
  key = request.env["HTTP_IDEMPOTENCY_KEY"]
  halt 400, { error: "missing idempotency key" }.to_json if key.nil? || key.empty?

  if rand < 0.1
    halt 429, { error: "rate limited" }.to_json
  end

  body = JSON.parse(request.body.read) rescue {}
  unless SEEN.include?(key)
    SEEN << key
    STORE[body["asin"]] = body
  end
  status 200
  { ok: true, asin: body["asin"], stored: STORE[body["asin"]] }.to_json
end

get "/listings/:asin" do
  content_type :json
  STORE[params[:asin]]&.to_json || halt(404)
end
