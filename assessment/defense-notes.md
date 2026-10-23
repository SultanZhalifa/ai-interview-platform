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

## Task D.1: test harness and CI

- RSpec was in the Gemfile but never initialized. Added `rails_helper`, factories for every
  interview model, `with_tenant` / `auth_headers_for` helpers, Sidekiq fake mode, and a guard:
  any spec that constructs a real `Gemini::HttpClient` fails. Services already take a
  `gemini_client:` argument, so a fake client is injected instead (no network, deterministic).
- `factories_spec.rb` checks every factory builds a valid record, so a broken factory fails
  loudly instead of producing confusing failures elsewhere.
- Vitest + React Testing Library + jest-dom in `web/`, one smoke test. CI runs RSpec against
  Postgres 16 and Redis 7, and `npm test` + `npm run build` (which runs `tsc`). The lockfile is
  committed so CI can use `npm ci` (closes setup defect S6).
- Locally verified by dropping the test DB and rebuilding it from `schema.rb`, as CI does.

## Task D.2: tenant isolation (F1, AC5)

- Root cause: only `Session`, `Assessment`, `Vacancy` have `tenant_id` + `TenantScoped`. Child
  records were loaded with `Portfolio.find(id)`, which ignores tenants.
- Fix: `Portfolio.in_current_tenant` = `joins(:session)`. Rails applies Session's default scope
  inside the join (`INNER JOIN sessions ON sessions.tenant_id = $1 AND ...`, seen in the log).
  Workers have no tenant set, so the default scope is a no-op there and they still find rows.
- Test first: 6 of 10 request examples failed before the fix (200/201/202/500 instead of 404),
  all pass after. One case was tightened while writing it: `regenerate_fitgap` returned 404 only
  because the attacker used the victim's vacancy id; with their own vacancy it went through.
- Re-checked with curl against the running server: cross-tenant 404, own data 200.

## Task D.3: parameter filtering (N1, AC10.1)

- Rails logs `Parameters:` at `info`, the production default, and this app had no filter, so
  login passwords were logged in plain text (seen in the dev log).
- Added the standard Rails filter list plus `email`, `candidate_name`, `assessor_notes`, and
  `text` matched exactly (so "context" is not hidden). Symbols match as substrings, which also
  covers `invite_token` and the `:token` path param (an invite token is a bearer secret).
- 8 of 9 examples failed before, all pass after; the dev log now shows `[FILTERED]`.

## Task D.4: not assessed, normalizer, confidence, atomic upsert (AC1-AC3, AC6.1-6.2)

- **Migration.** `assessment_status` (string + CHECK, not a PG enum: adding an enum value later
  cannot be rolled back in a transaction) and `status_reason`; `ai_level` / `ai_confidence`
  nullable. Two DB constraints make the honest state enforceable: a level exists exactly when
  the skill is `assessed`, and a `not_assessed` skill has no confidence. Existing rows default to
  `assessed` and already satisfy both. Down refuses (with a message) if any row has no level,
  rather than inventing L1s. Verified up / down / up and the refusal on dev data.
- **Where the skill list comes from.** The coverage map, not the model. The model can only fill in
  a rating for a skill the interview tracked; invented or duplicate skills are dropped (count
  logged, never content). No coverage map at all -> the assessment's skills, all not assessed.
- **When the model is called.** Only if the candidate spoke and at least one skill left `not_yet`.
  Budi's session now costs zero model calls and produces an honest "not assessed" portfolio.
- **Normalizer.** One place that turns model output into a valid row and never raises. Level
  accepts 3 / "3" / "L3" / 3.0; anything else is `needs_review`, never L1. Confidence is computed
  with the PRD rule (weakest matching label wins), so "High" can no longer crash a run.
- **Atomic and override-safe.** Rows are updated in place, matched by skill_id (any case) or
  label, inside a savepoint with a row lock. Stale skills are removed only if no assessor touched
  them. One real bug in my own first version was caught by the AC2.9 spec: the error path autosaved
  a half-built skill (AI log #4). I also gave a wrong explanation first and corrected it after
  testing it (AI log #3); be ready to explain non-joinable test transactions.
- **Fit/gap.** A skill with no effective level is reported as its status, never as a gap; the
  narrative prompt says these were not measured and must not be called strengths or weaknesses.
  An assessor override still counts as the effective level.

## Task D.5: fit/gap contract, overrides, one job at a time, PDF (AC4, AC6.3-6.4, AC7, AC8, AC9.1)

- **Contract.** `contracts/fit_gap_report.example.json` is the one shape both sides test against.
  `FitGap::ReportSerializer` fills every key for old JSONB rows, so reports stored before this
  change still render. `rules_version` (default 1 for existing rows) makes old reports `stale`;
  `outdated` means an override is newer than the report. No backfill of JSONB needed.
- **Provisional.** A low-confidence match/gap/exceed is flagged, unless an assessor overrode it:
  one question is not enough to call a gap, a human decision is.
- **Overrides.** Notes capped at 2,000 chars; a skill the interview never measured can be
  overridden only with a note, and that override stores no AI level (column made nullable,
  down-migration refuses if such rows exist). Saving an override no longer deletes the report.
- **One job at a time.** Redis `SET NX EX 300` per (portfolio, vacancy), taken at enqueue,
  released in the worker's `ensure`; TTL covers a dead worker. 3 POSTs -> 1 worker run, verified
  on the running server. Trade-off: an override always queues a refresh even if one is running,
  because the data changed; worst case is one extra model call.
- **Retries.** Each failed attempt keeps the portfolio `generating` with a readable reason and
  an attempt count; Sidekiq's exhausted hook marks it `failed`. Regenerate is 409 while active,
  allowed when failed or stalled (20 min: one attempt is at most ~12 min). The stalled clock
  starts when a job is queued (AI log #5 is the bug I caught there).
- **PDF.** Noto Sans (OFL, licence file committed) replaces the Windows-1252 built-ins. The font
  has no arrow glyph, so overrides are written in words; verified by rendering the PDF to PNG,
  not only by the spec. The table marks provisional / assessor-set rows and the narratives are
  labelled an AI-written draft. The model still writes a hiring recommendation (F9, escalated).

## Task D.6: frontend (AC1.5, AC4 UI, AC6.5, AC7.1, AC9.2-9.3, AC11)

- **Types first.** Making `types/index.ts` match the contract turned F3 into compile errors:
  `required_level` and `is_override` did not exist, and `parseLevel` (which turned null into L1)
  was the only thing keeping not-assessed skills "rated". It is deleted.
- **Contract test.** `ComparisonTable.test.tsx` renders `contracts/fit_gap_report.example.json`;
  the API's serializer spec checks the same file. Rename a field on either side and a suite fails.
- **One request.** `useFitGapReport` holds the rule: on 404 it POSTs once, then only polls GET,
  which now answers 202 while generating. Tested with fake timers (one POST across several polls)
  and seen in the browser network log: 404, POST 202, GET 202, GET 200.
- **States.** Not assessed / Needs review with the reason, provisional notes, override provenance
  (who, when, what it replaced), retry progress with the readable reason, stalled with Retry,
  failed with reason, load and export errors, partial ("4 of 5 skills assessed"), and nothing
  discussed (points to a new invitation, which is the right next step for a dropped connection).
- **Mobile.** Checked at 375 px in a real browser: no horizontal scroll (was 550 px), fit/gap rows
  stack so the result stays visible, card headers wrap instead of overlapping the button.
- **Design system.** Reused Card, Button, Select, LevelBadge, existing colour classes and lucide
  icons; added one small `Notice` component for inline warnings and errors. Emoji icons removed.
- **Test harness notes.** Testing Library's `waitFor` only knows Jest fake timers, so the hook
  test uses `shouldAdvanceTime`. A persistent `mockRejectedValue` made Vitest report the rejection
  even though the component caught it (verified with a log line); the test now uses
  `mockRejectedValueOnce` plus a call-count assertion. I did not find the root cause.

## Task E: seeded fault test

- Branch `scratch/seeded-fault` (off `16e5e82`), three fault commits, each followed by a
  `git revert` (not a reset), so the history shows the break and the fix. The tip is identical to
  the feature branch.
- Fault 1 `2b67f0b` / revert `c15c80d`: removed the `not_yet -> not_assessed` rule (F2).
  13 RSpec failures. 9 of them are `RecordInvalid` from the model validation, i.e. a second
  safety net (an assessed skill must have a confidence) caught it even before the assertions.
- Fault 2 `3c788f2` / revert `55382aa`: export back to `Portfolio.find` (F1). The two cross-tenant
  export specs fail (200 and 500 instead of 404).
- Fault 3 `c6dfe72` / revert `68178bb`: hook re-requests generation on every 202 (F7). Vitest
  reports `triggerFitGap` called 3 times instead of once.
- Picked one fault per layer the slice protects: scoring rule, tenant boundary, client polling.
- No assertion was edited on the scratch branch; only product code changed.

## Task G: report, video, PR

- The report (`assessment/report/report.html`, rendered with headless Chrome) mirrors Steps 1 to 5
  and is built from the documents in `assessment/`; every number in it was taken from the repo at
  render time (test counts from the suites, commit hashes from git). Re-render after adding the PR
  and video links.
- UU PDP articles were checked against the published text before citing (Pasal 10, 16, 34); no
  market statistics are quoted because none could be verified.
- Files were renumbered to match the brief's steps: 01 setup, 02 context, 03 findings, 04 strategy,
  05 execution.

## Lock ownership (follow-up to Task D.5)

- The lock now holds a token. `acquire` returns a UUID, `release` deletes the key only if it still
  holds that UUID (Lua compare-and-delete, atomic in Redis), and the worker gets the token as its
  third argument. A refresh queued after an override takes the lock if it is free and otherwise runs
  without it, leaving the running job's lock alone. Jobs queued before the change (two arguments)
  still run and simply do not release anything.
- Found by reviewing my own failure modes, not by a test: no spec had two jobs in flight. AI log #9.
- Still true: a run longer than the 5-minute TTL loses the lock; its stale token then cannot delete a
  newer holder's lock.
