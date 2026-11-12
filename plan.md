# Event Manager — Implementation Plan

## Product goal

Ruby gem that sits in a **transformation layer** between applications and event destinations. Callers use a **single unified** input/output shape; destination-specific structures (e.g. Toucan `tags`, `siteKeys`) stay inside the gem.

- **P1:** Query events (Toucan only).
- **P2:** Post/send events (deferred).
- **Distribution:** GitHub (Bundler `git:` source), not RubyGems.org.
- **Ruby:** >= 2.7.8 (production target includes 2.7.8p225 on x86_64-linux).

## Architecture (high level)

```
lib/event_manager/     # Facade, configuration, errors, versioning
destinations/toucan/   # Toucan strategy (same pattern for future destinations)
sig/                   # RBS types (as needed)
```

- **Configuration at init** selects destination strategy (e.g. Toucan).
- **`EventManager#query_events`** delegates to `destinations/toucan/service.rb`.

## Unified query contract (public API)

Documented in README and inline YARD. Users never need Toucan field names.

```ruby
EventManager.query_events(
  event_meta: {
    index: String,           # required — logical index name (mapped internally)
    operation_name: String   # required
  },
  filter: {
    users: [String],         # optional — filter by user identifiers (e.g. emails)
    date_range: {            # optional — both dates required when present
      start_date: String,
      end_date: String
    },
    site_keys: [String],     # optional — tenant/site scope
    account_id: String,      # optional
    event_types: [String]    # optional — restrict to configured event type ids
  },
  pagination: {
    from: Integer,           # default 1
    size: Integer            # default 20
  },
  optionals: {}              # optional — extension bag (see below)
)
```

**Response (unified):**

```ruby
{
  total: Integer,
  data: [
    {
      event: String,
      timestamp: String,     # ISO8601
      message: String,
      id: String,
      user: { email: String },
      metadata: Hash         # string keys → scalar values
    }
  ]
}
```

### `optionals` — tag-style filters

- **`optionals`** is a flat **key → value** Hash for filters that map to **destination tags** without exposing tag semantics to the caller.
- Document clearly: keys are **filter field names** the gem maps to native tags inside Toucan (e.g. `status`, `account_id` when not already in `filter`).
- Destinations may **ignore** unsupported keys or **reject** unknown keys (policy TBD; document behavior).
- Examples belong in README with copy-paste unified payloads.

### Cross-destination note

The shape above is the **canonical** query contract. Non-Toucan destinations validate and map only what they support; unsupported `filter` / `optionals` keys follow documented ignore/reject rules.

## P1 — Toucan query events (simplified stack)

No `toucan_query_mapping.json` in P1. Mapping is **imperative** in code (port from auth-master `ToucanQueryBuilder` / `ToucanQueryResponseBuilder` behavior).

| Piece | Responsibility |
|-------|----------------|
| `lib/event_manager.rb` | Facade: `configure`, `query_events` |
| `lib/event_manager/configuration.rb` | Destination, endpoint URL (env/configure) |
| `destinations/toucan/service.rb` | Orchestrate validate → build request → HTTP → build response |
| `destinations/toucan/validators/query_validator.rb` | Unified input rules (required meta, date range, pagination bounds, 90-day window for Toucan) |
| `destinations/toucan/builders/query_payload_builder.rb` | **`build_request(...)`** — unified args → native POST body; **`build_response(toucan_body)`** — native JSON → unified `{ total, data }` |
| `destinations/toucan/network/request.rb` | `POST /toucan/index/:index/events`, errors → gem errors |

**Explicitly not in P1**

- Request/response **adapter** classes (builder methods only).
- JSON mapping config files.
- `list_events` / catalog (can follow quickly after query).
- Post/write path, multi-destination registry, user-supplied destination JSON.

### Toucan query flow

1. `EventManager#query_events` normalizes keys.
2. `QueryValidator` on unified payload.
3. `QueryPayloadBuilder#build_request` → body + `index` for path.
4. `Network::Request#query_events(index:, **body)`.
5. `QueryPayloadBuilder#build_response` → unified result.

### Parity reference

Behavior aligned with:

- `auth-master` — `ToucanService#query_events`, `ToucanQueryBuilder`, `ToucanQueryResponseBuilder`, `Toucan::Request#query_events`, `EventNameCodec` for `event_types` slug encode/decode.

## Configuration

Set at **host app boot** (e.g. Rails initializer). Endpoint comes from **ENV**; destination **type** is an enum so other backends can be added later without changing the unified API.

```ruby
# config/initializers/event_manager.rb
EventManager.configure do |c|
  c.destination = {
    type: EventManager::Destination::TOUCAN, # enum, e.g. TOUCAN
    url: ENV.fetch("TOUCAN_EVENT_ENDPOINT")  # or ENV.fetch("TOUCAN_URL") — document one name
  }
end
```

- **`type`** — selects strategy (`destinations/toucan/`, etc.).
- **`url`** — base HTTP(S) URL for that destination’s network client (Toucan write/query host).
- Additional keys per type (timeouts, headers) can live on the same hash or nested `options:` later.
- Enum values are gem-defined constants; callers do not pass Toucan-specific paths or tag shapes here.

## Errors

### Goals

- **Configuration** failures are distinct (wrong/missing `destination` at boot, bad URL) — callers fix initializer/ENV.
- **Everything else** during `query_events` / future APIs inherits **`EventManager::Error`** and uses **`EventManager::<Specific>Error`** class names only (no ad-hoc `StandardError`, no leaking `Net::HTTP` types).
- Operational failures expose **context** for logging and support: **`destination_type`**, **`message`** (human-readable). Optional **`cause`** / **`http_code`** where relevant. Caller arguments are not attached to errors (log at call site if needed).

### Hierarchy

```
EventManager::Error                    # parent for runtime/query failures
├── EventManager::ValidationError      # unified input failed validation
├── EventManager::NetworkError         # HTTP / transport; only class with http_code
└── EventManager::ResponseError        # (optional) body parse / shape mismatch

EventManager::ConfigurationError       # boot/configure only; NOT raised from query_events path
```

- Rescue **`EventManager::Error`** in apps for all query-time failures.
- Rescue **`EventManager::ConfigurationError`** only around `EventManager.configure` or misconfiguration checks.

### Structured error payload

Each runtime error (subclasses of `EventManager::Error` except configuration) carries:

| Attribute | Type | Description |
|-----------|------|-------------|
| `destination_type` | Symbol | e.g. `:toucan` from `Configuration.destination_type` at time of call |
| `message` | String | Short summary for users/logs |
| `http_code` | Integer / Symbol | **NetworkError only** |
| `cause` | Exception | Optional wrapped inner error (internal); not required in public docs |

**Example (conceptual):**

```ruby
begin
  EventManager.query_events(...)
rescue EventManager::ValidationError => e
  e.destination_type   # => :toucan
  e.message            # => "event_meta.index is required"
end
```

Validation, query, and response builders/validators **raise** these types; they do not return error hashes on failure (Ruby convention).

### Where errors are raised

| Stage | Class | Notes |
|-------|--------|--------|
| `EventManager.configure` / missing URL | `ConfigurationError` | Boot/configure only |
| `QueryValidator` | `ValidationError` | Unified input rules |
| `QueryPayloadBuilder` | `ValidationError` | e.g. unparseable date at build time |
| `Network::Request` | `NetworkError` | Timeout, non-200, socket errors; include `http_code` |
| JSON parse of response | `ResponseError` | Include snippet-safe message |

### Documentation (README + YARD)

- Error hierarchy diagram or table (above).
- **ConfigurationError** vs **EventManager::Error** — when each appears.
- Every public error class: attributes (`destination_type`, `message`, `http_code` on `NetworkError`).
- Example `rescue` blocks for validation vs query failures.

### Implementation follow-up

- [x] Base class `EventManager::Error` with `destination_type`, `initialize(message:, destination_type:, **opts)`.
- [x] Subclasses: `ValidationError`, `NetworkError`, `ResponseError`.
- [x] Specs: validation and query failures assert context fields.
- [x] README “Errors” section.

## Gem packaging

- Include `lib/**` and `destinations/**` in `event_manager.gemspec` `spec.files`.
- README: installation via GitHub, unified API, `optionals` / tag filters, examples, env vars.

## Tests (P1)

- `QueryValidator` — required fields, date rules, pagination.
- `QueryPayloadBuilder#build_request` — fixture unified in → expected Toucan body (from auth-master examples).
- `QueryPayloadBuilder#build_response` — fixture Toucan JSON → unified shape.
- `Network::Request` — WebMock for URL, method, body.
- Optional facade integration spec end-to-end with stubbed HTTP.

## P2 backlog (not scheduled)

- Post events: `ToucanBuilder`-style path, validators, inventory/config.
- `list_events` from event catalog.
- Shared `Mapper` for `$path` templates if JSON config returns.
- Additional destinations under `destinations/<name>/` with same folder pattern:
  - `service.rb`, `validators/`, `builders/`, `network/request.rb`

## Documentation checklist

- [ ] Unified `query_events` parameters table (required / optional / defaults).
- [ ] Date format(s) accepted in `filter.date_range`.
- [ ] `filter.event_types` vs `optionals` — when to use which.
- [ ] `optionals` tag-filter semantics and examples.
- [ ] Unified response field descriptions.
- [ ] Configuration: initializer example, `destination.type` enum, ENV var for `destination.url`.
- [ ] GitHub install snippet for Gemfile.
- [ ] Error hierarchy, `destination_type`, rescue examples.
