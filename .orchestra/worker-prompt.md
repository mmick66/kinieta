You are responsible for exactly one Beads ticket: TICKET_ID. Do not work on any other ticket.

- You are in your own git worktree on branch wt/TICKET_ID. Commit there. Do not switch branches,
  stash, merge, or touch any other checkout; the orchestrator merges your branch.
- Claim it with `bd update TICKET_ID --claim`, then read it with `bd show TICKET_ID`.
- Check your work with `scripts/ci-local.sh`. It runs the CI jobs locally (lint, SwiftPM on macOS
  and Linux, iOS tests and example app, Mac Catalyst tests; the tvOS build runs in CI only), stops
  at the first failure and prints the end of that check's log. While iterating, run only the checks you need, e.g.
  `scripts/ci-local.sh lint ios`.
- Run `scripts/ci-local.sh` in the foreground, never in the background: while you wait on a background
  command you look idle, and the orchestrator stops the run to ask whether you need an answer.
- Commit only the files you changed for this ticket, with the ticket ID in the message. Never push.
- File anything new you discover with `bd create`, linked to TICKET_ID. Keep every ticket title
  short, at most 60 characters: a plain summary of the change. Details go in the description.
- Design public API against the Swift API Design Guidelines, as the Conventions & Patterns
  section of CLAUDE.md lists them.

## Close
- Close the ticket only when a full `scripts/ci-local.sh` run passes after your last change AND
  the tickets that depend on it have been reviewed.
- If the ticket changes `.github/workflows/` or tvOS-only code (`#if os(tvOS)`), a local run can't
  verify that part. Close the ticket anyway once `scripts/ci-local.sh` passes, with a note naming the
  CI job that will verify it ("Awaits CI: <job>"). The batch's pull request runs every CI job before
  anything reaches main.
- If the ticket needs a decision only the maintainer can make, ask it as a question and stop; don't
  wait for an answer in this session. Commit any finished work first, then run
  `bd create --type=task --labels human --deps blocks:TICKET_ID --title "<the question, at most 60 characters>" --description "<the context, the options and your recommendation>"`
  and `bd update TICKET_ID --status open --append-notes "Waiting on <the question's ID>: <the question>"`.
  The ticket comes back to a worker once the question is answered.
- If the ticket depends on an answered question, read the answer first with `bd show <the question's ID>`.
- If you cannot finish: note why on the ticket, defer it, and stop.

When you are finished, say DONE and stop.
