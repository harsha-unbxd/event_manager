# EventManager

Unified event **query** (and future send) API over pluggable destinations. Callers use one input/output shape; destination specifics (e.g. Toucan tags) stay inside the gem.

## Requirements

Ruby **>= 2.7.8** (stdlib only at runtime; no Rails dependency).

## Installation

This gem is installed from **GitHub** (not RubyGems.org). Your environment needs **git** available when Bundler resolves dependencies (`apk add git` / `apt install git` in Docker images if needed).

### `bundle add` (recommended)

From your app root:

```bash
bundle add event_manager \
  --git=https://github.com/harsha-unbxd/event_manager.git \
  --branch=main
```

Pin a commit:

```bash
bundle add event_manager \
  --git=https://github.com/harsha-unbxd/event_manager.git \
  --ref=<commit_sha>
```

GitHub shorthand:

```bash
bundle add event_manager --github=harsha-unbxd/event_manager --branch=main
```

Bundler updates `Gemfile`, runs `bundle install`, and locks the revision in `Gemfile.lock`.

### Manual `Gemfile` entry

```ruby
gem "event_manager", git: "https://github.com/harsha-unbxd/event_manager.git", branch: "main"
```

Then run `bundle install`.

## Configuration

In a Rails initializer (or at boot):

```ruby
# config/initializers/event_manager.rb
EventManager.configure do |c|
  c.destination = {
    type: EventManager::Destination::TOUCAN,
    url: ENV.fetch("TOUCAN_EVENT_ENDPOINT")
  }
end
```

| Key | Description |
|-----|-------------|
| `type` | `EventManager::Destination::TOUCAN` (more destinations later) |
| `url` | Base HTTP(S) URL for the destination API |

## Query events

**Recommended:** keep one `EventManager::Client` per process (initializer or app constant) and call `query_events` on it. That avoids creating a new client (and destination stack) on every request.

```ruby
# config/initializers/event_manager.rb (after EventManager.configure)
EVENT_MANAGER_CLIENT = EventManager::Client.new
```

```ruby
result = EVENT_MANAGER_CLIENT.query_events(
  event_meta: { topic: "account_activity" },
  filter: {
    site_keys: ["12345"],
    event_names: ["user_activity"],
    users: ["alice@example.com"],
    account_id: "SF-001",
    date_range: {
      start_date: "01/11/2025",
      end_date: "10/11/2025"
    },
    optionals: { status: "active", login_type: "sso" }
  },
  pagination: { from: 1, size: 20 }
)

# => { topic: String, total: Integer, data: [ { event_name:, timestamp:, message:, id:, user:, metadata: } ] }
```

### Parameters

| Section | Field | Required | Notes |
|---------|--------|----------|--------|
| `event_meta` | `topic` | yes | Logical topic name (Toucan: sent as `index` in the request path) |
| `filter` | `site_keys` | no | Array of site/tenant keys |
| `filter` | `event_names` | no | Unified event ids (`user_activity`); omitted when empty (Toucan → `operationNames`) |
| `filter` | `users` | no | User identifiers (e.g. emails) |
| `filter` | `account_id` | no | Account scope; also mapped to tag filters |
| `filter` | `date_range` | no | Both `start_date` and `end_date` required when set; max 90-day window |
| `filter` | `optionals` | no | Optional filters (key/value); merged into destination tag filters (see below) |
| `pagination` | `from`, `size` | no | Defaults `1`, `20`; max `size` 100 |

### Date formats

`filter.date_range` accepts **DD/MM/YYYY** or **YYYY-MM-DD**.

### Structured filters vs optional filters (all under `filter`)

**Structured fields** map to destination query/root parameters (`site_keys`, `event_names`, `users`, `date_range`, …). Toucan examples: `siteKeys`, `operationNames`, `users`, time bounds.

**Optional filters** use **`filter.optionals`** only. Each entry is merged (with `account_id` when set) into the destination **tags** object used for filtering. Toucan sends them as JSON `tags`.

```ruby
filter: {
  site_keys: ["12345"],
  event_names: ["user_activity"],
  optionals: { region: "us-east", status: "success", login_type: "sso" }
}
```

Callers use unified keys (e.g. `status`); the gem maps them to destination tags. Unsupported keys may be ignored or rejected per destination.

### Response

Top level: `topic` (echoes `event_meta.topic`), `total` (match count), `data` (rows).

Each row in `data` includes:

| Field | Description |
|-------|-------------|
| `event_name` | Unified event id (decoded from destination operation name; Toucan `operationName`) |
| `timestamp` | ISO8601 UTC |
| `message` | Human-readable message |
| `id` | Event id |
| `user` | `{ email: }` |
| `metadata` | All Toucan tags; keys strip trailing `_tag` (no other filtering) |

## Errors

| Class | When |
|-------|------|
| `EventManager::ConfigurationError` | `configure` / missing destination, invalid URL at boot — **not** a subclass of `EventManager::Error` |
| `EventManager::ValidationError` | Unified input invalid |
| `EventManager::NetworkError` | HTTP, timeout, socket / transport failures |
| `EventManager::ResponseError` | Response body could not be parsed |

Runtime errors inherit **`EventManager::Error`**. Each carries `message`, `destination_type`, and optional `cause`.

**Only `NetworkError`** exposes **`http_code`** (integer HTTP status or symbols such as `:request_timeout`, `:service_unavailable`).

```ruby
begin
  EventManager.query_events(...)
rescue EventManager::ValidationError => e
  e.destination_type
  e.message
rescue EventManager::NetworkError => e
  e.http_code
rescue EventManager::Error => e
  # ResponseError and other query-time failures
end
```

Log request context at the call site if you need it for debugging (the gem does not attach caller arguments to errors).

## Development

```bash
bin/setup
bundle exec rspec
```

## License

MIT (see LICENSE if present).
