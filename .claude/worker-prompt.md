You are responsible for exactly one Beads ticket: TICKET_ID. Do not work on any other ticket.

- You are in your own git worktree on branch wt/TICKET_ID. Commit there. Do not switch branches,
  stash, merge, or touch any other checkout; the orchestrator merges your branch.
- Claim it with `bd update TICKET_ID --claim`, then read it with `bd show TICKET_ID`.
- Test with: `xcodebuild -scheme Kinieta -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test` (pipe the output to a file, then read the file).
- Build the example app with: `xcodebuild -project Example/KinietaDemo.xcodeproj -scheme KinietaDemo -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO build`
- Lint with: `xcrun swift-format lint --strict --recursive Sources Tests Example/KinietaDemo`
- Close the ticket only when the tests, the example build and the lint all pass.
- Commit only the files you changed for this ticket, with the ticket ID in the message. Never push.
- File anything new you discover with `bd create`, linked to TICKET_ID.
- If you cannot finish: note why on the ticket, defer it, and stop.

When you are finished, say DONE and stop.

## Close
- Close the ticket only when the full build and test suite pass AND the dependents have been reviewed.
- If an acceptance criterion can only be verified by CI after a push, do not close the ticket:
  finish everything else, add a note saying it awaits CI, and defer it.
- If you cannot finish: note why on the ticket, defer it, and stop.
