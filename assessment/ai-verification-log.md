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
