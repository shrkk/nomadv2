---
phase: 01-foundation-spikes-globe-shell
plan: 02
subsystem: geojson-pipeline
tags: [geojson, parser, country-data, realitykit-prep]
dependency_graph:
  requires: [01-01]
  provides: [CountryFeature model, GeoJSONParser, countries-simplified.geojson]
  affects: [01-03-globe-rendering]
tech_stack:
  added: [mapshaper 0.6.113 (build tool only)]
  patterns: [Task.detached async parsing, Decodable custom init, GeoJSON RFC 7946]
key_files:
  created:
    - Nomad/GeoJSON/CountryFeature.swift
    - Nomad/GeoJSON/GeoJSONParser.swift
    - Nomad/Resources/countries-simplified.geojson
  modified:
    - Nomad.xcodeproj/project.pbxproj
decisions:
  - "Used mapshaper -filter-fields ISO_A2,NAME to strip all non-essential properties — reduced file from 651KB (geometry-only simplification) to 75KB"
  - "GeoJSONGeometry uses custom Decodable init to handle Polygon ([[[Double]]]) vs MultiPolygon ([[[[Double]]]]) coordinate nesting — enum with associated values"
  - "MultiPolygon flattened to single [[CLLocationCoordinate2D]] array (all rings merged) — simplest representation for Plan 03 texture-paint overlay approach"
  - "NomadTests target does not exist in project.pbxproj — test file skipped per plan context instructions"
metrics:
  duration: ~15 minutes
  completed: 2026-04-04T23:09:10Z
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 1
---

# Phase 01 Plan 02: GeoJSON Pipeline Summary

GeoJSON pipeline delivering 75KB pre-simplified Natural Earth 110m country polygons with async Decodable parser filtering disputed territories via ISO_A2 != "-99".

## Tasks Completed

| # | Name | Commit | Key Files |
|---|------|--------|-----------|
| 1 | Bundle simplified Natural Earth 110m GeoJSON | 05ee41d | Nomad/Resources/countries-simplified.geojson, Nomad.xcodeproj/project.pbxproj |
| 2 | Implement CountryFeature model and async GeoJSONParser | 8a4df68 | Nomad/GeoJSON/CountryFeature.swift, Nomad/GeoJSON/GeoJSONParser.swift |

## Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| countries-simplified.geojson exists and is under 300KB | PASS — 75,389 bytes |
| Contains ISO_A2 (at least 100 occurrences) | PASS — 177 occurrences |
| Contains "type": "FeatureCollection" | PASS |
| Contains "Polygon" or "MultiPolygon" geometry types | PASS — 158 Polygon + 19 MultiPolygon |
| CountryFeature.swift: struct CountryFeature: Identifiable | PASS |
| CountryFeature.swift: let isoCode: String | PASS |
| CountryFeature.swift: let polygons: [[CLLocationCoordinate2D]] | PASS |
| CountryFeature.swift: struct GeoJSONFeatureCollection: Decodable | PASS |
| CountryFeature.swift: struct GeoJSONGeometry: Decodable | PASS |
| GeoJSONParser.swift: func loadCountries() async throws -> [CountryFeature] | PASS |
| GeoJSONParser.swift: Task.detached(priority: .userInitiated) | PASS |
| GeoJSONParser.swift: references "countries-simplified" | PASS |
| GeoJSONParser.swift: filters ISO_A2 != "-99" | PASS |
| NomadTests/GeoJSONParserTests.swift exists with 3+ test methods | SKIPPED — no NomadTests target |
| Project builds cleanly on iOS 18 simulator | PASS — xcodebuild -quiet returns 0 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] mapshaper 15% simplification produced 651KB file (over 300KB limit)**
- **Found during:** Task 1
- **Issue:** Simplifying geometry to 15% still left the file at 651KB because Natural Earth features carry ~100 properties per feature
- **Fix:** Added `-filter-fields ISO_A2,NAME` to the mapshaper pipeline, stripping all non-essential properties. Result: 75KB (87% smaller)
- **Files modified:** Nomad/Resources/countries-simplified.geojson
- **Commit:** 05ee41d

### Skipped Items (per plan context instructions)

**NomadTests/GeoJSONParserTests.swift** — The plan calls for a TDD test file in NomadTests target. No NomadTests target exists in Nomad.xcodeproj. Per the execution context: "If a NomadTests target doesn't exist in the project, skip the test file and note it in the SUMMARY.md." The test file was not created. Plan 03 or a future infrastructure plan should add the XCTest target and wire GeoJSONParserTests at that point.

## Known Stubs

None — all data is live (parsed from real Natural Earth dataset). GeoJSONParser.loadCountries() returns real country data when called on device/simulator.

## Self-Check

### Created files exist
- Nomad/GeoJSON/CountryFeature.swift: FOUND
- Nomad/GeoJSON/GeoJSONParser.swift: FOUND
- Nomad/Resources/countries-simplified.geojson: FOUND

### Commits exist
- 05ee41d (Task 1): FOUND
- 8a4df68 (Task 2): FOUND

## Self-Check: PASSED
