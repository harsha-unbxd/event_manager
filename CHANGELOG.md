# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-12

### Added

- **Unified query API** — `EventManager::Client#query_events` and module-level `EventManager.query_events` with a single input shape (`event_meta`, `filter`, `pagination`, `optionals`) and normalized response (`total`, `data` rows with `event`, `timestamp`, `message`, `id`, `user`, `metadata`).
- **Destination configuration** — `EventManager.configure` with `destination: { type:, url: }`; first supported type is `EventManager::Destination::TOUCAN`.
- **Toucan destination** — Pluggable stack: validation → request builder → HTTP client → response builder (`destinations/toucan/`).
- **Filters** — Optional `site_keys`, `users`, `event_types`, `account_id`, and `date_range`; arbitrary tag filters via `optionals` (mapped to Toucan tags without exposing destination field names).
- **Pagination** — Defaults `from: 1`, `size: 20`; maximum page size 100.
- **Date range validation** — Accepts `DD/MM/YYYY` or `YYYY-MM-DD`; requires both bounds when set; enforces a 90-day lookback and end date not after today.
- **Event naming** — `EventNameCodec` maps unified event type ids to/from destination-specific values.
- **Metadata** — Toucan tags normalized in responses (`metadata`); `_tag` suffix stripped on keys via `Helpers::TagMetadata`.
- **Error types** — `ConfigurationError` (boot/config), `ValidationError`, `NetworkError` (includes `http_code`), and `ResponseError`; runtime query failures inherit `EventManager::Error` with `destination_type` and optional `cause`.
- **HTTP layer** — Toucan queries over stdlib `Net::HTTP` only (no runtime gem dependencies beyond Ruby >= 2.7.8).
- **Developer tooling** — RSpec suite with WebMock, RuboCop (including rubocop-rspec), default `rake` task, and GitHub Actions CI on Ruby 2.7.8 and 3.4.9.

### Documentation

- README covers installation from GitHub, configuration, query parameters, response fields, and error handling.
