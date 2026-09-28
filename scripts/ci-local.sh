#!/usr/bin/env bash
# Run the checks from .github/workflows/ci.yml on this machine, stopping at the first failure.
#
#   scripts/ci-local.sh                  every check, fastest first
#   scripts/ci-local.sh lint ios         only the named checks, in the order given
#
# Checks (each mirrors one CI job):
#   lint        swift-format lint                        (job: lint)
#   spm-macos   swift build + swift test on the Mac host (job: spm-macos)
#   ios        iOS Simulator tests + example app build  (job: test)
#   catalyst    Mac Catalyst tests                       (job: catalyst)
#   spm-linux   swift build + swift test in Docker       (job: spm-linux)
#
# The tvOS build and the visionOS tests (jobs: tvos, visionos) run in CI only.
#
# Requires Xcode 26.6 with the iOS 26.5 simulator runtime, and a running Docker for spm-linux.
# Full output of each check goes to .build/ci-local/<check>.log; on a failure the end of it is
# printed. xcbeautify, if installed, condenses xcodebuild failures to their errors.
#
# Exit codes: 0 all requested checks passed, 1 a check failed, 2 usage or setup problem.

set -euo pipefail

ALL_CHECKS=(lint spm-macos ios catalyst spm-linux)

# Snapshot references in Tests/KinietaTests/__Snapshots__ were recorded on this simulator and
# runtime. Keep in sync with DESTINATION in .github/workflows/ci.yml and README "Development".
DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
LINUX_IMAGE=swift:6.3

cd "$(git rev-parse --show-toplevel)"
LOG_DIR=.build/ci-local
mkdir -p "$LOG_DIR"

# ---- Checks ------------------------------------------------------------------------

check_lint() {
  xcrun swift-format lint --strict --recursive Sources Tests Example/KinietaDemo
}

check_spm-macos() {
  swift build && swift test
}

check_ios() {
  xcodebuild -scheme Kinieta -destination "$DESTINATION" -derivedDataPath DerivedData test \
    && xcodebuild -project Example/KinietaDemo.xcodeproj -scheme KinietaDemo \
      -destination "$DESTINATION" -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
}

check_catalyst() {
  xcodebuild -scheme Kinieta -destination 'platform=macOS,variant=Mac Catalyst' \
    -derivedDataPath DerivedData test
}

# A separate scratch path keeps the Linux build products apart from the host's .build.
check_spm-linux() {
  docker run --rm -v "$PWD:/src" -w /src "$LINUX_IMAGE" \
    bash -c 'swift build --scratch-path .build-linux && swift test --scratch-path .build-linux'
}

# ---- Arguments and setup -----------------------------------------------------------

usage() { sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; }

case "${1:-}" in -h|--help) usage; exit 0 ;; esac

if [ "$#" -gt 0 ]; then checks=("$@"); else checks=("${ALL_CHECKS[@]}"); fi

for c in "${checks[@]}"; do
  case " ${ALL_CHECKS[*]} " in
    *" $c "*) ;;
    *) echo "Unknown check: $c (choose from: ${ALL_CHECKS[*]})" >&2; exit 2 ;;
  esac
done

# Missing tools are setup problems, reported before anything runs rather than as a failed check.
wants() { case " ${checks[*]} " in *" $1 "*) return 0 ;; esac; return 1; }
runtimes=$(xcrun simctl list runtimes 2>/dev/null || true)
problems=()
if wants ios && ! grep -q '^iOS 26\.5 ' <<<"$runtimes"; then
  problems+=("ios needs the iOS 26.5 simulator runtime. Install it with: xcodebuild -downloadPlatform iOS -buildVersion 26.5")
fi
if wants spm-linux && ! docker info >/dev/null 2>&1; then
  problems+=("spm-linux needs Docker, and it is not running.")
fi
if [ "${#problems[@]}" -gt 0 ]; then
  echo "ci-local.sh cannot start:" >&2
  for p in "${problems[@]}"; do echo "  - $p" >&2; done
  exit 2
fi

# ---- Run ---------------------------------------------------------------------------

for c in "${checks[@]}"; do
  log="$LOG_DIR/$c.log"
  printf '%-10s ' "$c"
  start=$SECONDS
  if "check_$c" >"$log" 2>&1; then
    # Swift Testing's summary; XCTest's "Executed 0 tests" line is always zero here.
    tests=$(sed -n 's/.*Test run with \([0-9]*\) tests\{0,1\} .*/\1/p' "$log" | tail -n 1)
    echo "passed ($((SECONDS - start))s${tests:+, $tests tests})"
  else
    echo "FAILED ($((SECONDS - start))s); full log: $log"
    echo
    # xcbeautify drops xcodebuild's own errors (bad destination, missing scheme), so only
    # condense build and test failures.
    if command -v xcbeautify >/dev/null 2>&1 && grep -q '^Command line invocation:' "$log" \
      && ! grep -q '^xcodebuild: error:' "$log"; then
      xcbeautify --quieter --is-ci --disable-logging --disable-colored-output <"$log" | tail -n 40
    else
      tail -n 40 "$log"
    fi
    exit 1
  fi
done

echo "All ${#checks[@]} checks passed."
