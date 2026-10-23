# AI verification log

Real instances where AI-generated code or commands (Claude Code, pairing with me) were wrong or
risky, and how they were caught. Appended as they happen.

## 1. False "every model returns 404" diagnosis (2026-10-23, Task B)

- **What was generated:** a zsh loop to test which Gemini models work:
  `curl ... "https://generativelanguage.googleapis.com/$v/models/$m:generateContent"`.
- **What went wrong:** every model, including ones that work, came back 404 with an empty body.
  The tempting conclusion was "the key cannot call any model".
- **Why it was wrong:** in zsh, `$m:g...` is parsed as a history-style modifier on `$m`, so the
  URL sent was not the URL written. The 404s were caused by the test, not by Gemini.
- **How it was caught:** an empty-body 404 is unusual for a Google API, so I sent one request
  with headers dumped (`curl -D -`) instead of trusting the status code. It returned 200.
  Re-ran the loop with `${m}` braces.
- **Fix:** `${v}` / `${m}` in every URL. No commit involved (local diagnostics only).
- **Lesson kept:** check the raw response before concluding from a status code.

## 2. "The model exists, so it works" (2026-10-23, Task B)

- **What was generated:** a check that called `GET /v1/models/<id>` and treated 200 as "usable";
  on that basis `GEMINI_PRO_MODEL` was switched to `gemini-2.5-pro`.
- **What went wrong:** the metadata endpoint returned 200, but `generateContent` returned 404:
  "This model ... is no longer available to new users".
- **How it was caught:** the portfolio still failed after the switch; the full error body was in
  `log/development.log` (the stored `generation_error` only said "API returned 404", which is
  itself finding N2).
- **Fix:** test models with a real `generateContent` call. Local config now uses
  `gemini-2.5-flash`, documented as an assumption in `03-findings.md`.

## 3. Nested transaction that did not roll back (2026-10-24, Task D, AC2.9)

- **What was generated:** `save_skills` wrapped in `ActiveRecord::Base.transaction do ... end`.
- **Why it was risky:** a nested `transaction` call without `requires_new: true` does not create a
  savepoint. If a caller already holds a transaction (the RSpec example does; a future caller
  could), an exception inside propagates without undoing the rows written before it.
- **How it was caught:** the AC2.9 spec ("leaves every previous skill untouched when saving fails
  halfway") failed: the React skill had been updated even though a later save raised.
- **Fix:** `transaction(requires_new: true)`. The spec still failed after this, which led to #4.

## 4. Half-written skill saved by the error path (2026-10-24, Task D, AC2.9)

- **What was generated:** new skills built with `portfolio.portfolio_skills.build`, and the
  existing `rescue` in `Generator#call` marks the portfolio failed with `portfolio.update!`.
- **Why it was wrong:** a built record stays in the has_many association. When the save inside the
  transaction failed, the rescue's `portfolio.update!` autosaved that unsaved skill, outside the
  rolled-back transaction. A failed generation would leave a partial portfolio behind, which is
  exactly F5. This would also happen in production (Sidekiq has no outer transaction).
- **How it was caught:** the same spec still reported 3 skills instead of 2. Instead of guessing, I
  printed the surviving rows: the extra one was the skill whose save had raised.
- **Fix:** create new rows with `PortfolioSkill.new(portfolio_id: portfolio.id)`, with a comment on
  why. Both fixes are needed; the spec now passes and stays as a regression guard.
