require "sinatra"
require "json"
require "set"

set :port, ENV.fetch("PORT", 4002).to_i
set :bind, "0.0.0.0"

SEEN = Set.new
STORE = {}

post "/items" do
  content_type :json
  key = request.env["HTTP_IDEMPOTENCY_KEY"]
  halt 400, { error: "missing idempotency key" }.to_json if key.nil? || key.empty?

  if rand < 0.05
    halt 500, { error: "transient failure" }.to_json
  end

  body = JSON.parse(request.body.read) rescue {}
  unless SEEN.include?(key)
    SEEN << key
    STORE[body["itemId"]] = body
  end
  status 200
  { ok: true, itemId: body["itemId"], stored: STORE[body["itemId"]] }.to_json
end

get "/items/:id" do
  content_type :json
  STORE[params[:id]]&.to_json || halt(404)
end
