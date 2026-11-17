# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Topic** — `event_meta.topic` replaces `event_meta.index` in unified input; unified response now includes top-level `topic`. Toucan wire format unchanged (still `/toucan/index/:index/events`).
- **Query filters** — `filter.event_names` replaces `event_meta.operation_name`, `filter.event_types`, and `filter.operation_names`. Toucan requests send root `operationNames` (array); event-type tag filtering is removed from the query path.
- **Event codec** — `filter.event_names` are encoded on the way out (Toucan `operationNames`); each row returns `event_name` decoded from the destination operation name.
- **Optional filters** — Top-level `optionals` removed; use `filter.optionals` only (mapped to destination tags). `filter.tags` is not part of the unified input.
- **Adapters** — Toucan query builders renamed to `destinations/toucan/adapters/` (`QueryRequestAdapter#adapt`, `QueryResponseAdapter#adapt`).
- **Query pipeline** — `Client#query_events` calls `validate!`, `adapt`, `dispatch`, `adapt_response_to_unified` on each destination; `destinations/base.rb` defines the interface.

### Removed

- **`event_meta.index`** — use `event_meta.topic` instead.
- **`event_meta.operation_name`** — use `filter.event_names` instead.
- **`filter.event_types`** / **`filter.operation_names`** — use `filter.event_names` instead.
- **Top-level `optionals`** / **`filter.tags`** — use `filter.optionals` instead.

## [0.1.0] - 2026-11-12

### Added

- **Unified query API** — `EventManager::Client#query_events` and module-level `EventManager.query_events` with a single input shape (`event_meta`, `filter`, `pagination`, `optionals`) and normalized response (`total`, `data` rows with `event`, `timestamp`, `message`, `id`, `user`, `metadata`).
- **Destination configuration** — `EventManager.configure` with `destination: { type:, url: }`; first supported type is `EventManager::Destination::TOUCAN`.
- **Toucan destination** — Pluggable stack: validation → request builder → HTTP client → response builder (`destinations/toucan/`).
- **Filters** — Optional `site_keys`, `users`, `event_types`, `account_id`, and `date_range`; arbitrary tag filters via `optionals` (mapped to Toucan tags without exposing destination field names).
- **Pagination** — Defaults `from: 1`, `size: 20`; maximum page size 100.
- **Date range validation** — Accepts `DD/MM/YYYY` or `YYYY-MM-DD`; requires both bounds when set; enforces a 90-day lookback and end date not after today.
- **Operation naming** — `EventNameCodec` maps unified operation ids to/from Toucan dot notation (`user_activity` ↔ `user.activity`).
- **Metadata** — Toucan tags normalized in responses (`metadata`); `_tag` suffix stripped on keys via `Helpers::TagMetadata`.
- **Error types** — `ConfigurationError` (boot/config), `ValidationError`, `NetworkError` (includes `http_code`), and `ResponseError`; runtime query failures inherit `EventManager::Error` with `destination_type` and optional `cause`.
- **HTTP layer** — Toucan queries over stdlib `Net::HTTP` only (no runtime gem dependencies beyond Ruby >= 2.7.8).
- **Developer tooling** — RSpec suite with WebMock, RuboCop (including rubocop-rspec), default `rake` task, and GitHub Actions CI on Ruby 2.7.8 and 3.4.9.

### Documentation

- README covers installation from GitHub, configuration, query parameters, response fields, and error handling.
