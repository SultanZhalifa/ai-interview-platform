# Defense notes

Short "how to explain this" notes, one per meaningful change or decision.

## Setup: why Puma runs with WEB_CONCURRENCY=0 locally

- `puma.rb` runs 2 forked workers with `preload_app!`. On macOS, Objective-C runtime fork
  safety kills a forked child that touches certain system classes, so each worker crashed on
  its first request and curl saw an empty reply.
- Single mode (`WEB_CONCURRENCY=0`) does not fork, so it avoids the crash. It is a local-only
  env var: no repo change, production on Linux is unaffected.
- Trade-off: `on_worker_boot` (which restarts EventMachine per worker) does not run in single
  mode. That matters for the live audio WebSocket path, which is out of the revamp scope.

## Task B: how the findings were verified

- Real flow, seeded inputs: sessions were ended through the real API, so portfolio generation,
  fit/gap and export ran through Sidekiq and Gemini. Only the transcript and coverage map were
  seeded, because the live audio interview is not reproducible on demand. Say this upfront.
- Tenant isolation was tested the way an attacker would: a valid token from company A against
  company B's integer ids. Endpoints that load through `Session` returned 404 (the control),
  endpoints that load `Portfolio`/`PortfolioSkill` directly returned data and accepted writes.
- The malformed-output test used the generator's existing `gemini_client:` injection seam
  inside a transaction that is rolled back, so no real data was changed.
- Two findings were downgraded after runtime checks (F4 not observed wrong, F8 only loses the
  report if the job never runs). Being able to say what did NOT reproduce is part of the story.

## Task C: the three decisions most likely to be challenged

- **Status column instead of "no row" for not-assessed skills.** A portfolio should be a complete
  account of the interview. With no row there is nowhere to put "needs review", and every future
  reader (engine, PDF, JSON, UI) must remember to merge coverage maps back in, which is exactly
  how F2 happened. Down-migration refuses to run if NULL levels exist, instead of inventing L1s.
- **Tenant scope through `joins(:session)` now, `tenant_id` columns later.** Verified that Rails
  7.0 applies Session's default scope inside the join. It closes the P0 without a production data
  migration; request specs per endpoint pin it. Two-layer isolation is the follow-up.
- **Keep `expected_level` in the API, fix the web, add a shared contract file.** The bug was two
  sides drifting with nothing to notice. The contract example is read by both RSpec and Vitest,
  so a rename on either side fails a test.
