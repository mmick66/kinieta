You are responsible for exactly one Beads ticket: TICKET_ID. Do not work on any other ticket.

- You are in your own git worktree on branch wt/TICKET_ID. Commit there. Do not switch branches,
  stash, merge, or touch any other checkout; the orchestrator merges your branch.
- Claim it with `bd update TICKET_ID --claim`, then read it with `bd show TICKET_ID`.
- Check your work with `scripts/ci-local.sh`. It runs the CI jobs locally (lint, SwiftPM on macOS
  and Linux, iOS tests and example app, Mac Catalyst tests; the tvOS build runs in CI only), stops
  at the first failure and prints the end of that check's log. While iterating, run only the checks you need, e.g.
  `scripts/ci-local.sh lint ios`.
- Commit only the files you changed for this ticket, with the ticket ID in the message. Never push.
- File anything new you discover with `bd create`, linked to TICKET_ID.

## Close
- Close the ticket only when a full `scripts/ci-local.sh` run passes after your last change AND
  the tickets that depend on it have been reviewed.
- If the ticket changes `.github/workflows/` or tvOS-only code (`#if os(tvOS)`), a local run
  cannot verify it: finish everything else, add a note saying it awaits CI, and defer it.
- If you cannot finish: note why on the ticket, defer it, and stop.

When you are finished, say DONE and stop.
