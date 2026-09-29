#if canImport(UIKit) || os(macOS)
import Testing

@testable import Kinieta

extension Trait where Self == SharedEngineTrait {
    /// Runs each test of the suite alone among all tests with this trait.
    ///
    /// Give it to every suite that drives `Engine.shared`: tests install their own
    /// frame driver and change settings such as `isReduceMotionEnabled` and
    /// `colorInterpolation` for a moment, and `.serialized` alone only orders the
    /// tests inside one suite, while separate suites run in parallel.
    static var usesSharedEngine: Self { SharedEngineTrait() }
}

/// Holds a lock on `Engine.shared` for the whole of each test case, including the
/// suite's `init`, so no test sees another's driver or temporary settings.
struct SharedEngineTrait: SuiteTrait, TestTrait, TestScoping {
    var isRecursive: Bool { true }

    func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
        // One lock per test case; the suite and the test function hold none, so
        // nothing takes the lock twice.
        testCase == nil ? nil : self
    }

    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        await SharedEngineLock.shared.acquire()
        do {
            try await function()
        } catch {
            await SharedEngineLock.shared.release()
            throw error
        }
        await SharedEngineLock.shared.release()
    }
}

/// A first-come, first-served lock that suspends waiters instead of blocking the
/// main thread, which every test runs on.
@MainActor
private final class SharedEngineLock {
    static let shared = SharedEngineLock()

    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        guard isHeld else {
            isHeld = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    /// Hands the lock straight to the next waiter, so no newcomer can overtake it.
    func release() {
        if waiters.isEmpty {
            isHeld = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
#endif
