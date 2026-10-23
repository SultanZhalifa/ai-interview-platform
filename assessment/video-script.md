# Video walkthrough script (target 4:00, hard limit 5:00)

For Sultan to record. English, spoken, first person. Learn the flow, not the exact words. Times are
cumulative. Use the local app with the fake candidates (Rina, Budi); never show `application.yml`,
`.env`, a terminal with a token, or the browser's DevTools Network headers (they contain the JWT).

## Before recording

- Services running: Sidekiq, `WEB_CONCURRENCY=0 bundle exec rails server -p 3001`, `npm run dev`.
- To show the before state, check out `main` in a second worktree, or use the screenshots in
  `assessment/screenshots/before/`. Simplest: show the screenshots for "before" and the live app for
  "after". Say which one you are showing.
- Have open: Budi's fit/gap page, Rina's portfolio, Rina's fit/gap page, a terminal at `api/` and
  one at `web/` (clean, no tokens in scrollback), and `assessment/evidence/seeded-fault-1-*.txt`.
- Zoom the browser to 110 % so text is readable in the recording.

## 0:00 - 0:35 The problem and who it hurts

Show `B04-audio-failure-becomes-gap-everywhere.jpg`.

> "So, this platform runs an AI voice interview, rates the candidate's skills, and writes a report
> for the hiring manager. The problem I found is that it can't tell 'we didn't measure this' apart
> from 'the candidate is bad at this'.
>
> Take Budi. He's a fake candidate, and his audio cut out after one sentence. But look: Gap on every
> skill, the Required column is empty, and the summary says he's not ready. Nobody even asked him a
> question. For a real person, that's getting rejected because of a bad connection."

## 0:35 - 1:00 How I found it

Show the findings table in the report for two seconds; no need to read it.

> "I didn't want to guess from the code, so I ran everything locally. I made fake candidates in two
> companies and pushed them through the real API, the workers and Gemini. I ended up with sixteen
> findings. Two were really serious. Skills nobody measured got rated L1. And an assessor could see
> another company's candidates just by changing an id in the URL."

## 1:00 - 2:05 After: the same candidates

Live app, Budi's portfolio:

> "So here's Budi now. Every skill says Not assessed, with the reason. And the page tells the
> assessor what to do next: invite him again."

Budi's fit/gap page:

> "Same on the fit/gap page. The required level is there now, and the summary says it can't make a
> recommendation from this interview."

Rina's portfolio, scroll to Testing and Communication:

> "Rina actually had a proper interview. Testing only came up once, so it's marked provisional.
> Communication never came up. I overrode it myself and left a note, and you can see the card says
> a person changed it."

Rina's fit/gap page:

> "Here in the comparison you can see that too. One skill is provisional, one was set by a person.
> And this one the interview never covered, so it says Not assessed, not Gap."

Click PDF, open the downloaded file for two seconds:

> "Exporting this to PDF used to crash with a server error once someone overrode a skill. Now it
> works, even with Indonesian text, and the AI part is labelled as a draft."

## 2:05 - 2:30 Edge and error states

Show `A04-override-unassessed-requires-note.jpg`, then `A06-mobile-fitgap-stacked.jpg` next to
`B07-mobile-fitgap-result-column-hidden.jpg`.

> "A few smaller things. If you override a skill that wasn't measured, you have to write a note. If
> generation is retrying, you see why. And on mobile, the table stacks now. Before, the result
> column was hidden off the side of the screen."

## 2:30 - 3:15 Proof

Terminal at `api/`:

```bash
bundle exec rspec
```

> "There were no tests at all before. Now there are 151 on the backend..."

Terminal at `web/`:

```bash
npm test
```

> "...and 33 on the frontend. To check they actually catch bugs, I broke the main rule on purpose,
> on a separate branch."

Show `assessment/evidence/seeded-fault-1-not-assessed-rule.txt` (top of the file).

> "Thirteen tests failed. Then I reverted it with git revert, so you can see it in the history. I
> did the same for the tenant check and for the polling bug."

## 3:15 - 3:45 One trade-off

> "One decision I'd stand behind: I made 'not assessed' a real status in the database, with a
> constraint. The easier option was to just not save those skills. But then every screen and every
> export has to remember to add them back, and forgetting that is exactly what caused this bug.
> With the constraint, the database itself won't accept a level for a skill nobody measured."

## 3:45 - 4:00 What I did not do

> "What I didn't do: consent and data deletion under UU PDP, plus one question about how tokens
> pick a tenant. Those need product and legal input, so I wrote them up instead of guessing. It's
> all in the report and the PR. Thanks!"

## Checklist after recording

- Duration between 3:00 and 5:00.
- No token, key, real name or email visible in any frame (scrub the recording once).
- Upload as unlisted (YouTube) or link-shared (Drive / Loom); paste the link into the report cover
  and the PR description.
