#!/usr/bin/env bash
# Run the per-frame cost benchmarks (Tests/KinietaTests/Benchmarks.swift) in release mode and
# print what each frame, step or call costs, the best of several runs.
#
#   scripts/bench.sh                     macOS host, on NSView (swift test -c release)
#   scripts/bench.sh ios                 iOS Simulator, on UIView (xcodebuild -configuration Release)
#   scripts/bench.sh macos ios           both, in the order given
#
# Compare a refactor by running it before and after on the same idle machine: the numbers are
# only comparable with each other, never with another machine's, so the benchmarks are not a
# pass/fail test and normal test runs and CI skip them (they run only with KINIETA_BENCH=1,
# which this script sets). The release build is compiled with -enable-testing so the suite's
# @testable import still works.
#
# Full output of each run goes to .build/bench/<platform>.log; on a failure the end of it is
# printed.
#
# Exit codes: 0 every requested run passed, 1 a run failed, 2 usage problem.

set -euo pipefail

ALL_PLATFORMS=(macos ios)

# Keep in sync with DESTINATION in scripts/ci-local.sh.
DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'

cd "$(git rev-parse --show-toplevel)"
LOG_DIR=.build/bench
mkdir -p "$LOG_DIR"

export KINIETA_BENCH=1

bench_macos() {
  swift test -c release -Xswiftc -enable-testing --filter Benchmarks
}

# xcodebuild passes TEST_RUNNER_-prefixed variables to the test process without the prefix.
bench_ios() {
  TEST_RUNNER_KINIETA_BENCH=1 xcodebuild -scheme Kinieta -destination "$DESTINATION" \
    -derivedDataPath .build/bench/DerivedData -configuration Release ENABLE_TESTABILITY=YES \
    -only-testing:KinietaTests/Benchmarks test
}

usage() { sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; }

case "${1:-}" in -h|--help) usage; exit 0 ;; esac

if [ "$#" -gt 0 ]; then platforms=("$@"); else platforms=(macos); fi
for p in "${platforms[@]}"; do
  case " ${ALL_PLATFORMS[*]} " in
    *" $p "*) ;;
    *) echo "Unknown platform: $p (choose from: ${ALL_PLATFORMS[*]})" >&2; exit 2 ;;
  esac
done

for p in "${platforms[@]}"; do
  log="$LOG_DIR/$p.log"
  echo "$p:"
  if "bench_$p" >"$log" 2>&1; then
    lines=$(sed -n 's/^\[bench\] /  /p' "$log")
    if [ -z "$lines" ]; then
      echo "  no benchmark ran; full log: $log" >&2
      exit 1
    fi
    echo "$lines"
  else
    echo "  FAILED; full log: $log"
    echo
    tail -n 40 "$log"
    exit 1
  fi
done
