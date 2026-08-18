# Resonance model-layer contract

Read the repository root `AGENTS.md` and `Docs/ARCHITECTURE.md` before changing a
model. Models describe durable data and identity; stores and services own mutation
and I/O.

## Model responsibilities

- `Track.swift` owns the stable track representation, Codable compatibility, value
  semantics, and derived display values that do not require I/O.
- Model changes must preserve stable IDs, persisted field meaning, optional-field
  compatibility, deterministic ordering inputs, and remote/local identity rules.
- Normalization used to compare artist, album, or track identity must remain explicit
  and deterministic. Do not silently change grouping keys in a presentation change.

## Model boundaries

- Models must not perform network requests, filesystem scans, SQLite writes, tag
  writes, audio graph setup, or SwiftUI layout.
- Computed properties may format or derive values from model fields, but expensive
  decoding, provider work, and broad projections belong to their owning services.
- When a field is persisted or transmitted, document migration/default behavior before
  changing it and keep older stored data readable where feasible.

## Change checklist

Record identity, compatibility, and ordering effects in `Docs/WORK-QUEUE.md`. Validate
Swift parsing, regression contracts, and any serialization fixtures affected by the
change. Do not infer runtime acceptance from model tests alone.
