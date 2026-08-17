# Debug Session: River/Ferry Temple Calculation Errors

**Session ID**: `river-ferry-calculations`
**Status**: [OPEN] ✓ All fixes verified — awaiting user confirmation before cleanup
**Created**: 2026-08-17
**Affected Modules**: `trip_model.dart`, `create_trip_screen.dart`, `trip_detail_screen.dart`, `multimodal_route_service.dart`
**Symptom**: QA reports errors when performing calculations related to temples requiring river/water crossing (ferry), primarily in map and trip screens. Distances and durations show incorrect values.

---

## Falsifiable Hypotheses — Evidence Verdict

| #   | Hypothesis                                                                   | Evidence Collected                                                                                                                                                                                                                                                                              | Verdict                        |
| --- | ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ | ----------------------------------------------------------------- | ------------------------ |
| H1  | `Trip.getTotalDistance()` returns 0 when ALL legs have null `distanceToNext` | **Pre-fix evidence test output:** `getTotalDistance() = 0.0 km` for [Ananda→TantKyi] with null distances. **Post-fix:** New `Trip.getTotalDistance()` iterates `stops[0..N-2]` via `getLegDistance(index)` which falls back to haversine, so total now = **7.5 km** for same data.              | ✅ **CONFIRMED + FIXED**       |
| H2  | `_saveTrip()` skips distance calculation for ferry pairs                     | Static code analysis: old `_saveTrip()` set `distanceToNext = null` whenever `requiresFerry` was true. Refactored to pre-compute every adjacent pair using the SAME strategy as `_buildFerryAwareDistanceCalculator()` — BOTH detection methods + `buildPlan().distanceKm` for true ferry legs. | ✅ **CONFIRMED + FIXED**       |
| H3  | TripDetailScreen hardcodes "12 min" fallback                                 | Static code confirmed. Replaced with `_formatLegDistance(index)` → calls `Trip.getLegDistance(index)` → uses stored value OR coordinate-based haversine. Legacy trips + freshly saved trips now all show real distances.                                                                        | ✅ **CONFIRMED + FIXED**       |
| H4  | Ferry detection in save vs optimize inconsistent                             | Old save used ONLY `PathfindingService.requiresRiverCrossingBetween`. New save uses BOTH `requiresRiverCrossingBetween(...)                                                                                                                                                                     |                                | routeUsesFerry([from,to])`, matching `\_optimizeRoute()` exactly. | ✅ **CONFIRMED + FIXED** |
| H5  | `_buildFerryAwareDistanceCalculator` haversine fallback misleading           | Added an intermediate fallback tier: `_graphAwareDistanceBetween(a,b,graph)` used before raw haversine for mainland/mainland pairs not in pre-compute cache. Ferry pairs will never hit this due to the earlier detection & `buildPlan` use.                                                    | ⚠️ **LOW PRIORITY — IMPROVED** |

---

## Evidence Log

| Timestamp  | Observation                                                                                                      | Related Hypothesis | Status                         |
| ---------- | ---------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------ |
| 2026-08-17 | Test evidence H1: `getTotalDistance = 0.0` for null-distance ferry trip                                          | H1                 | Pre-fix confirmed              |
| 2026-08-17 | Test evidence H4: `requiresRiverCrossingBetween = true`, `routeUsesFerry = true` both agree for Bupaya<->TantKyi | H4                 | Detection confirmed consistent |
| 2026-08-17 | **26/26 tests pass** (6 existing regression tests + 15 new trip-distance tests + remaining tests)                | All hypotheses     | Post-fix ✅ VERIFIED           |

---

## Changes (All Fixes Applied)

| Change                                                                                                                                                                                                                     | File                                                                                                                            | Type             | Lines            |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ---------------- |
| Added `getLegDistance(int index)` with haversine fallback; rewrote `getTotalDistance()` to use it; added private `_haversineBetween` with `dart:math` import                                                               | [trip_model.dart](file:///D:/Project/baganetic_mobile/lib/data/models/trip_model.dart#L1-L137)                                  | Fix (H1, H3)     | 1, 98-136        |
| Refactored `_saveTrip()`: pre-computes `pairDistanceCache` for all adjacent pairs using BOTH ferry predicates and `MultimodalRouteService.buildPlan().distanceKm` for ferry legs — 100% consistent with `_optimizeRoute()` | [create_trip_screen.dart](file:///D:/Project/baganetic_mobile/lib/presentation/screens/trips/create_trip_screen.dart#L123-L209) | Fix (H2, H4)     | 123-209          |
| Improved `_buildFerryAwareDistanceCalculator` fallback chain: now tries graph distance before raw haversine                                                                                                                | [create_trip_screen.dart](file:///D:/Project/baganetic_mobile/lib/presentation/screens/trips/create_trip_screen.dart#L457-L473) | Improvement (H5) | 457-473          |
| Replaced hardcoded "12 min" fallback with `_formatLegDistance(index)` → `Trip.getLegDistance(index)`                                                                                                                       | [trip_detail_screen.dart](file:///D:/Project/baganetic_mobile/lib/presentation/screens/trips/trip_detail_screen.dart#L472-L502) | Fix (H3)         | 472-502, 530-533 |
| New: comprehensive test suite (15 tests) covering stored-distance, null-distance fallback, mixed legacy data, last-stop edge cases, duration calc, ferry detection predicate parity, pathfinding & multimodal regressions  | [trip_ferry_distance_test.dart](file:///D:/Project/baganetic_mobile/test/core/data/trip_ferry_distance_test.dart)               | Tests            | —                |

---

## QA Test Checklist (Recommended Manual Validation)

- [ ] Create a 2-stop trip: Ananda → Tant Kyi Taung. Save → open Trip Detail. Verify header shows non-zero distance (≈7–9 km, depending on road/ferry geometry used).
- [ ] Next-leg line under the first pagoda should now show a REAL `X.XX KM` value, never "12 MIN".
- [ ] Create a 3+ stop trip that includes Tant Kyi Taung (e.g. Ananda, Tant Kyi Taung, Shwezigon). Optimize → Save. Verify all stops have plausible distances.
- [ ] Multi-stop with ferry → `Edit` trip → re-save → verify distances preserved/recalculated correctly.
- [ ] In Map screen → Trips mode → select the saved ferry trip: verify dashed blue ferry line, Bu Paya + Tant Kyi jetties shown with boat icons, "Ferry transfer" pill appears.
- [ ] Map screen → Path mode: Ananda → Tant Kyi Taung, click Find Route: verify it picks the multimodal plan (ferry badge, dashed blue polyline, correct terminals).
- [ ] Non-ferry regression check: Create Ananda → Shwezigon → Thatbyinnyu trip: no ferry, should behave exactly as before (no null distances, optimize still uses 2-opt correctly).
