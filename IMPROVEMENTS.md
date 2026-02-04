# Baganetic Mobile - Improvement Plan (v2)

This plan narrows scope for a realistic 12-week delivery cycle and separates
must-do work from roadmap items.

## Guiding Principles

1. Stability before scale: reliability and observability come first.
2. Security and privacy are baseline requirements, not late-stage extras.
3. Ship in thin vertical slices with measurable outcomes every sprint.
4. Keep "Now" scope strict; move speculative/large bets to "Later".

## Now / Next / Later

## Now (Weeks 1-12, committed)

### Reliability and Quality
- Unit tests for providers/services/models in core flows
- Widget tests for auth, discovery, trip, and chat entry screens
- Integration smoke tests for login, discovery browse, chat send, trip save
- CI gate: run tests on every PR and block merge on failures

### Error Handling and Resilience
- Unified error model for API/network/cache/auth failures
- Offline-aware states and retry with exponential backoff
- User-facing localized error messages for top failure cases
- Global crash-safe boundaries around critical app shells/screens

### Observability and Performance
- Crash reporting and performance traces enabled in production
- Baseline dashboards: crash-free sessions, startup time, API latency
- Startup optimization (target p95 under 2.5s on mid-range devices)
- Memory/perf pass on map, discovery list, and chat threads

### Security and Privacy (moved up)
- Encrypt sensitive local data at rest (tokens/user-specific records)
- Permission minimization and clear consent prompts
- Basic threat model + secure config checklist for releases
- Data deletion/export support for user account data

### UX Foundation
- Lightweight onboarding for first-session guidance
- Accessibility pass (screen reader labels, tap targets, contrast)
- System theme support (light/dark parity for key screens)

## Next (post-12 weeks, near-term roadmap)

- Discovery filters and sort-by-distance improvements
- Push notifications for chat and important trip updates
- Cloud sync for trips/favorites across signed-in devices
- User feedback module and in-app issue reporting
- A/B testing framework (after analytics baseline is stable)

## Later (future bets, not current commitment)

- Turn-by-turn navigation and traffic-aware rerouting
- AI recommendations, assistant/chatbot, image recognition
- Real-time booking integrations and full review ecosystem
- Web/desktop clients and broad multi-platform expansion

## 12-Week Delivery Plan (MVP)

## Sprint 1 (Weeks 1-2): Baseline and Instrumentation
- Set up crash/performance monitoring and release logging
- Establish test harness and CI checks (unit/widget/integration smoke)
- Define error taxonomy and common failure handling patterns
- Deliverable: health dashboard + first protected CI pipeline

## Sprint 2 (Weeks 3-4): Core Flow Hardening
- Harden auth/discovery/trip/chat with loading/error/empty states
- Add retries and offline-safe behavior to key repositories
- Add first wave of unit/widget tests for critical paths
- Deliverable: stable core flow with measurable crash reduction

## Sprint 3 (Weeks 5-6): Performance Pass
- Optimize startup path and initialization order
- Improve list/map image loading and cache behavior
- Review expensive database/API calls and remove bottlenecks
- Deliverable: p95 startup and memory targets reached on test devices

## Sprint 4 (Weeks 7-8): Security and Privacy Foundations
- Apply encryption and secure token/data handling
- Complete permission audit and privacy UX copy
- Add account-level data deletion/export pathways
- Deliverable: security checklist complete for production release

## Sprint 5 (Weeks 9-10): UX and Accessibility
- Ship onboarding v1 and improve first-use clarity
- Complete accessibility pass on high-traffic screens
- Ensure dark/light theme parity and basic UI polish
- Deliverable: improved task completion in usability checks

## Sprint 6 (Weeks 11-12): Stabilization and Release
- Regression testing, bug bash, and release readiness sweep
- Finalize observability alerts and incident runbook
- Validate metrics against targets and prepare roadmap handoff
- Deliverable: production candidate + post-release monitoring plan

## Success Metrics (12-week targets)

## Engineering
- Crash-free sessions: >= 99.5%
- Startup time: p95 < 2.5s (target devices)
- API error recovery success after retry: >= 85%
- Test coverage on critical modules: >= 70%

## Product and UX
- Core task success (login, discovery, trip save, chat send): >= 92%
- First-week retention: +10% relative uplift from current baseline
- Accessibility audit issues (critical): 0 open before release
- Support tickets related to crashes/login failures: -30% from baseline

## Delivery and Team Capacity

### Team (current assumption)
- 1 Flutter engineer (full-time)
- 1 backend engineer (part-time)
- 1 QA/support engineer (part-time)
- 1 product/design contributor (part-time)

### Scope Guardrails
- Any new item entering "Now" must replace something of similar effort
- High-uncertainty features (AI, multi-platform expansion) stay in "Later"
- Prioritize quality gates over adding net-new features late in cycle

---

Last Updated: February 3, 2026
Project: Baganetic Mobile Improvement Plan (v2)
