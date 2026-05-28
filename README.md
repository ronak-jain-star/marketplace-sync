# Marketplace Sync

> Reference implementation of a multi-marketplace listing sync service —
> the canonical answer to *"design a system that pushes product listings
> to Amazon, Flipkart, Walmart, eBay."*

Built to demonstrate **senior / staff-level distributed systems patterns** in a
self-contained, runnable Rails app.

![Tests](https://img.shields.io/badge/tests-36%20passing-brightgreen)
![Ruby](https://img.shields.io/badge/ruby-3.4.1-red)
![Rails](https://img.shields.io/badge/rails-8.0.5-red)

---

## What this demonstrates

Senior-level patterns wired end-to-end:

| Pattern | Where |
|---|---|
| **Transactional Outbox** | `app/services/listings/upsert.rb` writes catalog change + N events in one DB transaction |
| **Outbox → log relay** | `OutboxRelay` polls with `FOR UPDATE SKIP LOCKED`, publishes to Redis Streams |
| **Per-key ordering** | Stream per channel; consumer rejects `version <= applied_version` |
| **At-least-once with consumer groups** | Redis Streams `XREADGROUP` + `XACK` semantics |
| **Idempotency** | Idempotency key = `sku:channel:version` passed to every marketplace call |
| **Token-bucket rate limiting** | Atomic Lua script in Redis, scoped per `(channel, seller_id)` |
| **Exponential backoff + jitter** | `ChannelConsumer` retries, dead-letters after `MAX_RETRIES` |
| **Adapter pattern** | Each marketplace is one folder under `app/services/channels/` |
| **Reconciler-ready model** | `channel_listings` separates `desired_version` vs `applied_version` |

---

## Architecture

```
    Seller UI / API client
              │
              ▼
    ┌─────────────────────┐
    │ Listing API (Rails) │
    └──────────┬──────────┘
               │  (DB transaction)
        ┌──────┴──────┐
        ▼             ▼
   listings      listing_events  ◄── Transactional Outbox
                       │
                       ▼
              ┌─────────────────┐
              │  OutboxRelay    │  (FOR UPDATE SKIP LOCKED)
              └────────┬────────┘
                       │ XADD
                       ▼
     ┌────────────────────────────────────┐
     │ Redis Streams (one per channel)    │
     │   listing.events.amazon            │
     │   listing.events.walmart           │
     └─────────────┬──────────────────────┘
                   │ XREADGROUP
   ┌───────────────┼───────────────┐
   ▼               ▼               ▼
ChannelConsumer  ChannelConsumer  ChannelConsumer
 (amazon)         (walmart)         (eBay …)
   │
   ├── Token-bucket RateLimiter (per channel, seller)
   ├── Channels::Amazon::Adapter / Walmart / …
   ▼
Marketplace API (or fake in /fakes for local demo)
```

---

## Run it

```bash
# Prereqs: Postgres + Redis running locally (defaults: 5432 / 6379).
# brew services start postgresql@14 redis  # macOS

# Install + migrate
bundle install
bin/rails db:create db:migrate

# Boot everything (Rails API + Sidekiq + outbox relay + 2 consumers + 2 fakes)
bundle exec foreman start -f Procfile.dev
```

The Procfile runs 7 processes:

| Process | What it does | Port |
|---|---|---|
| `web` | Rails API | 3001 |
| `sidekiq` | Background jobs | — |
| `outbox` | DB → Redis Streams relay | — |
| `amazon_consumer` | Drains `listing.events.amazon` | — |
| `walmart_consumer` | Drains `listing.events.walmart` | — |
| `fake_amazon` | Sinatra fake of Amazon SP-API | 4001 |
| `fake_walmart` | Sinatra fake of Walmart Marketplace API | 4002 |

### Demo

```bash
# Create a listing
curl -X POST http://localhost:3001/api/v1/listings \
  -H 'Content-Type: application/json' \
  -d '{
    "sku":"SKU-1",
    "seller_id":"seller-A",
    "title":"Wireless Earbuds",
    "price_cents":4999,
    "inventory_qty":100
  }'

# Inspect per-channel sync status
curl http://localhost:3001/api/v1/listings/SKU-1 | jq

# Update price → v=2 → both channels re-sync
curl -X PUT http://localhost:3001/api/v1/listings/SKU-1 \
  -H 'Content-Type: application/json' \
  -d '{"seller_id":"seller-A","title":"Wireless Earbuds","price_cents":3999,"inventory_qty":100}'
```

Within ~1 second each channel transitions `pending → in_flight → live`.
The fake Amazon returns 429 on ~10% of writes, the fake Walmart returns 500
on ~5%, exercising the retry path.

---

## Tests

```bash
bundle exec rspec
# 36 examples, 0 failures, ~0.3s
```

The suite uses:

- **`test-prof` `before_all`** for DB factory data — set up once per group, rolled back per example via savepoints.
- **FactoryBot** with `sequence(:sku)` to avoid uniqueness collisions.
- **WebMock** to stub marketplace HTTP calls in the adapter and consumer specs.
- **Real Redis on db 15** for spec runs — `mock_redis` can't execute Lua scripts (`EVAL`) or streams reliably.

What's covered:

| Spec | Examples |
|---|---|
| `Listings::Upsert` — create, update, restricted channels | 7 |
| `OutboxRelay` — relay, idempotency, skip published | 6 |
| `RateLimiter` — burst, scoped buckets | 3 |
| `Channels::Adapter`, `Amazon::Adapter` — push, 429, 5xx | 6 |
| `ChannelConsumer` — success, version skip, retry, dead-letter | 6 |
| `Api::V1::ListingsController` request specs | 8 |

---

## Project layout

```
app/
├── controllers/api/v1/listings_controller.rb   # REST surface
├── models/
│   ├── listing.rb
│   ├── channel_listing.rb                      # per-channel sync state
│   └── listing_event.rb                        # outbox row
└── services/
    ├── listings/upsert.rb                      # transactional outbox writer
    ├── outbox_relay.rb                         # DB → Redis Streams
    ├── channel_consumer.rb                     # Redis Streams → adapter
    ├── rate_limiter.rb                         # token bucket (Lua)
    └── channels/
        ├── adapter.rb                          # factory
        ├── amazon/adapter.rb
        └── walmart/adapter.rb

fakes/                                          # Sinatra services that
├── amazon_server.rb                            #  honour Idempotency-Key,
└── walmart_server.rb                           #  return 429 / 5xx randomly

spec/                                           # 36 examples
├── rails_helper.rb                             # before_all, real Redis db 15
├── factories.rb
├── services/
└── requests/api/v1/
```

---

## Talking points for an interview

The numbered points map directly to the architecture diagram:

1. **"Catalog writes and event emission share a transaction — outbox."**
   No event lost; no event duplicated at source. `Listings::Upsert#call`.
2. **"Stream is partitioned by channel; consumer enforces per-SKU monotonic version."**
   Late events are silently dropped (`version <= applied_version`).
3. **"Rate limit is per (seller, channel)."**
   Global limits would serialise unrelated sellers under one noisy neighbour.
4. **"Idempotency key is content-addressable."**
   Same `sku:channel:version` → same effect on the marketplace, safe to retry.
5. **"Failures backoff with jitter; dead-letter goes to status='error'."**
   Surfaced via `GET /listings/:sku` so support sees the failure.
6. **"Adapter pattern means adding eBay or Flipkart is one folder."**
   Core path doesn't change.
7. **"A reconciler (nightly) closes the eventual-consistency gap."**
   `desired_version` vs `applied_version` columns make this trivial.

---

## What's intentionally out of scope

- Real SP-API / Flipkart auth (LWA + AWS SigV4 / OAuth2). Fakes simulate the wire protocol.
- Multi-region.
- Real Kafka (Redis Streams gives the same semantics at this scale).
- Image hosting / category schema validation.
- Webhook ingestion (marketplace → us). Stub planned.

---

## Branch model

| Branch | Purpose | Protected |
|---|---|---|
| `production` | Stable, default branch | Yes — PR required, force-push and deletion blocked |
| `main` | Working branch | No — fast iteration, PRs into `production` |

Open a PR from `main → production` to see every file as a new addition.

---

## License

MIT. Build whatever you want on top of this.
# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
