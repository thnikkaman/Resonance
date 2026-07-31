# Self-Test

## Positive triggers

1. “Test the fixture server’s byte-range behavior without mocks.”
   - Trigger Tier A and run the bundled harness.
2. “Verify Navidrome playlists, favorites, and streaming end to end.”
   - Trigger Tier B after a written isolated-server safety declaration.
3. “Reproduce the remote seek bug on an iPhone.”
   - Trigger Tiers B-D; separate real-service, simulator, install, launch, and physical acceptance evidence.

## Negative triggers

1. “Unit test the album sort key.”
   - A pure deterministic unit test is enough; do not provision a service.
2. “Why is range streaming slow?”
   - Use this skill for correctness fixtures, then `resonance-profile-performance` for measurement.
3. “Split RemoteLibraryStore.”
   - Route to `resonance-decompose-isomorphically` and use this skill as its real-service gate.

## Contract checks

A correct run must block unknown/production endpoints, never echo credentials, use disposable state, assert both client and server/file/database truth, clean only run-owned resources, and state exactly which tier supports each claim.
