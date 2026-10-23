# Never report a rating the interview did not earn

Case study submission (Sultan Z. M.). One PR across `api/` and `web/`. Report:
<!-- report link or "attached in the hiring platform" --> · Video: <!-- video link -->

## Problem

The platform could not tell "we did not measure this" from "the candidate is weak at this". A skill
the interview never reached was stored as L1, shown as "L1 Foundational", reported as a Gap, and
written into the hiring narrative. A candidate whose audio dropped after one sentence got Gap on
every skill and "not yet at the level to independently contribute". The Required column was blank
on every fit/gap report, confidence was hidden, and correcting a rating broke the PDF export.
Separately, any assessor could export, rescore or run fit/gap on another tenant's candidate by
changing an integer id.

All of this was reproduced on a running system with fake data; findings, severities and evidence
are in `assessment/03-findings.md` and `assessment/evidence/`.

## Options considered

Full comparison in `assessment/04-revamp-strategy.md` (written before any code). The main calls:

| Decision | Chosen | Rejected |
|---|---|---|
| Not assessed | Status column, nullable level, DB check constraints | No row (no place for needs review, every reader must re-merge); sentinel level 0 |
| Tenant isolation | Scope through `Session` (default scope applies inside the join) | `tenant_id` on child tables now (production backfill; proposed as follow-up) |
| Fit/gap contract | Keep `expected_level`, fix the web, shared contract file tested by both suites | Rename the API field; fix the web only |
| Model output | Server-side normalizer per skill | Rely on JSON-schema mode alone |
| Duplicate jobs | UI POSTs once + Redis lock per (portfolio, vacancy) | UI only; `sidekiq-unique-jobs` |
| PDF text | Embed Noto Sans (OFL) | Transliterate to Windows-1252 |

## What changed

**API**
- `portfolio_skills.assessment_status` (`assessed` / `not_assessed` / `needs_review`) and
  `status_reason`; `ai_level` and `ai_confidence` nullable; check constraints: a level exists
  exactly when the skill is assessed, an unassessed skill has no confidence.
- Generator: skill list from the coverage map; no model call when nothing was discussed;
  `Portfolios::SkillNormalizer` validates each skill and never raises; confidence from the PRD rule
  (`Coverage::Confidence`); in-place upsert in a savepoint with a row lock, so overrides survive;
  readable failure reasons; `failed` only when Sidekiq retries run out.
- Fit/gap: unmeasured skills are `not_assessed` / `needs_review`, never a gap; `provisional`,
  `overridden`, `ai_level` per row; narratives from competency summaries; `FitGap::ReportSerializer`
  with defaults for stored reports and `stale` / `outdated` / `generating`; `FitGap::GenerationLock`.
- Tenant scope on every id-based portfolio lookup (`in_current_tenant`).
- Overrides: notes up to 2,000 chars, note required for unassessed skills; reports kept, not
  deleted, while a refresh runs.
- Regenerate: 409 while a run is active, allowed when failed or stalled for 20 minutes.
- PDF: Noto Sans; overrides in words; provisional and assessor-set results marked; AI text labelled.
- `filter_parameter_logging`: passwords, tokens, emails, candidate names, notes, transcript text.

**Web**
- Types mirror `contracts/fit_gap_report.example.json`; `parseLevel` (null to L1) removed.
- `ComparisonTable`, `SkillPortfolioCard`, `OverridePanel`, `PortfolioPage`, `FitGapReportPage`
  handle loading, empty, not assessed, needs review, provisional, partial, generating with attempts,
  stalled, failed with reason, load and export errors, long text, 375 px.
- `useFitGapReport`: one generation request, then polling.
- New `Notice` component; emoji icons replaced with lucide icons already in use.

**Harness**
- RSpec set up (factories, tenancy helpers, a guard that fails any spec building a real Gemini
  client); Vitest + Testing Library; GitHub Actions running both.

## Migrations

All four are reversible and were run up, down and up on existing rows. Existing rows get safe
defaults (`assessed`, `rules_version = 1`, `generation_attempts = 0`). The two that relax NOT NULL
refuse to roll back, with a message, while rows without a level exist, instead of inventing L1s.

## How to test

```bash
cd api && bundle exec rails db:migrate && bundle exec rspec
cd web && npm ci && npm test && npm run build
```

Manual: end a session with one candidate turn and open its portfolio and fit/gap page (every skill
Not assessed, no model call); override a skill and export the PDF; open the fit/gap page and check
the Network tab (one POST); try a portfolio id from another tenant (404).

## Proof

- Red then green for every group: `assessment/evidence/tests/`.
- Seeded faults on `scratch/seeded-fault`, each reverted with `git revert`: the not-assessed rule
  (`2b67f0b` / `c15c80d`, 13 failures), the tenant scope (`3c788f2` / `55382aa`, 2 failures), and
  re-requesting fit/gap while polling (`c6dfe72` / `68178bb`, 2 failures).
- AI verification log with seven real entries: `assessment/ai-verification-log.md`.

## Screenshots

Before and after: `assessment/screenshots/before/` and `assessment/screenshots/after/`
<!-- attach the key pairs here when opening the PR: B04/A09, B03/A05, B07/A06, A01 -->

## Risks

- Portfolios generated before this change keep their stored L1 values until regenerated; fit/gap
  reports built before it are flagged stale in the UI and PDF. No backfill is run automatically.
- The Redis lock has a 5-minute TTL; a run longer than that could overlap with a new request.
- Local verification used `gemini-2.5-flash`; the sample config's model ids return 404 on new keys.
- The model still writes a hiring recommendation, now labelled as a draft.

## Follow-ups (not in this PR)

1. Consent notice, retention and deletion for candidate data; a way for candidates to object
   (UU PDP Pasal 10, 16, 34).
2. Confirm whether rakamin-api ever issues tokens without `scheme` (tenant selection by header).
3. `tenant_id` on child tables as a second isolation layer.
4. Production model ids and API version; JSON-schema output on top of the normalizer.
5. Backfill for old portfolios; evidence grounding.
