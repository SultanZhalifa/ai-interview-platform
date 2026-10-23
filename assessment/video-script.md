# Video walkthrough script (target 4:30, hard limit 5:00)

For Sultan to record. English, spoken, first person. Times are cumulative. Use the local app with the
fake candidates (Rina, Budi); never show `application.yml`, `.env`, a terminal with a token, or the
browser's DevTools Network headers (they contain the JWT).

## Before recording

- Services running: Sidekiq, `WEB_CONCURRENCY=0 bundle exec rails server -p 3001`, `npm run dev`.
- To show the before state, check out `main` in a second worktree, or use the screenshots in
  `assessment/screenshots/before/`. Simplest: show the screenshots for "before" and the live app for
  "after". Say which one you are showing.
- Have open: Budi's fit/gap page, Rina's portfolio, Rina's fit/gap page, a terminal at `api/` and
  one at `web/` (clean, no tokens in scrollback), and `assessment/evidence/seeded-fault-1-*.txt`.
- Zoom the browser to 110 % so text is readable in the recording.

## 0:00 - 0:35 The problem and who it hurts

> "This platform interviews a candidate with an AI voice, rates their skills, and writes a fit/gap
> report a hiring manager reads. I found it could not tell 'we didn't measure this' from 'the
> candidate is weak at this'. Here is Budi, a fake candidate whose audio broke after one sentence."

Show `B04-audio-failure-becomes-gap-everywhere.jpg`.

> "Before: Gap on every skill, the Required column empty, and a narrative saying he's not ready.
> Nobody asked him a single question. For a real person, that's a rejection caused by a bad
> connection."

## 0:35 - 1:05 How I found it

> "I didn't trust the code reading. I ran both services, seeded realistic interviews for fake
> candidates in two companies, and pushed them through the real API, workers and Gemini. That turned
> up sixteen findings. The two P0s: unmeasured skills rated as L1, and any assessor being able to
> read and rescore another company's candidates by changing an id."

Show the findings table in the report for two seconds; no need to read it.

## 1:05 - 2:20 After: the same candidates

Live app, Budi's portfolio:

> "Now every skill says Not assessed, with the reason, and the page tells the assessor what to do:
> invite him again."

Budi's fit/gap page:

> "Fit/gap shows the required level on every row, and the narrative says a recommendation can't be
> made from this interview."

Rina's portfolio, scroll to Testing and Communication:

> "Rina had a real interview. Testing was asked once, so it's marked provisional. Communication was
> never discussed; I overrode it with a note, and the card shows that a human set it, when, and what
> it replaced."

Rina's fit/gap page:

> "In the comparison, the one-question match is provisional, the human rating is labelled, and the
> skill the vacancy needs but the interview never covered is Not assessed, not a gap."

Click PDF, open the downloaded file for two seconds:

> "Exporting a corrected portfolio used to return a server error. Now it works, including
> Indonesian text and non-Latin names, and the AI text is labelled as a draft."

## 2:20 - 2:50 Edge and error states

Show quickly, from the app or the after screenshots:

> "Override of an unmeasured skill requires a note. Generation that's retrying shows the attempt and
> the reason. A stalled run can be restarted. On a phone, the comparison stacks so the result is
> always visible; before, the page scrolled sideways and hid it."

Show `A06-mobile-fitgap-stacked.jpg` next to `B07-mobile-fitgap-result-column-hidden.jpg`.

## 2:50 - 3:40 Proof

Terminal at `api/`:

```bash
bundle exec rspec
```

> "There were no tests and no CI. There are now 144 backend examples..."

Terminal at `web/`:

```bash
npm test
```

> "...and 33 frontend tests. To prove they're real, I broke the not-assessed rule on a scratch
> branch."

Show `assessment/evidence/seeded-fault-1-not-assessed-rule.txt` (top of the file).

> "Thirteen specs failed, nine of them stopped by the database model's own validation, so there are
> two layers. Then I reverted it with git revert so the history stays visible. Same for the tenant
> check and the duplicate-request bug."

## 3:40 - 4:10 One trade-off

> "The decision I'd defend first: I stored 'not assessed' as an explicit status with a database
> constraint, rather than just not saving those skills. Not saving them looks simpler, but every
> future screen, export or report would have to remember to add them back. That's exactly how this
> bug happened. With the constraint, the database refuses a level on a skill nobody measured."

## 4:10 - 4:30 What I did not do

> "What's deferred: consent, retention and deletion for candidate data under UU PDP, and a question
> for the team about tokens without a tenant claim. Those need product and legal decisions, so I
> documented them instead of guessing. Everything is in the report and the PR. Thanks."

## Checklist after recording

- Duration between 3:00 and 5:00.
- No token, key, real name or email visible in any frame (scrub the recording once).
- Upload as unlisted (YouTube) or link-shared (Drive / Loom); paste the link into the report cover
  and the PR description.
