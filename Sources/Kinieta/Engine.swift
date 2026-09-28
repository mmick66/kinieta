/*
 * Engine.swift
 * Created by Michael Michailidis on 16/10/2017.
 * http://blog.karmadust.com/
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#if canImport(UIKit)
import UIKit
import os

/// Delivers frames to the engine while it has actions that can make progress.
///
/// Production uses `Engine.DisplayLinkDriver`; tests install a manual driver
/// and step frames by hand so timelines run deterministically.
@MainActor
protocol FrameDriver: AnyObject {
    /// `true` between `start(onFrame:)` and `stop()`.
    var isRunning: Bool { get }
    /// The frame rates the driver asks the display for. Applies immediately
    /// while running, and to every later `start(onFrame:)`.
    var preferredFrameRateRange: CAFrameRateRange { get set }
    /// Starts delivering frames to `onFrame`. Does nothing if already running.
    func start(onFrame: @escaping (Engine.Frame) -> Void)
    /// Stops delivering frames and releases `onFrame`.
    func stop()
}

@MainActor
public final class Engine {

    /// One tick of the engine clock.
    struct Frame: Sendable {
        /// Time elapsed since the previous frame, in seconds. Actions advance by this amount.
        var duration: TimeInterval
        init(_ duration: TimeInterval) {
            self.duration = duration
        }
    }

    /// Turns display-link timestamps into elapsed-time frames.
    ///
    /// Advancing by the real elapsed time, rather than the nominal frame
    /// interval, keeps animations on schedule when frames are dropped and on
    /// displays whose refresh rate varies.
    struct FrameClock {
        /// A gap longer than this (the app was suspended, the debugger paused)
        /// is treated as one nominal frame instead of a jump to the end state.
        static let maximumGap: TimeInterval = 1.0

        private var lastTimestamp: TimeInterval?

        mutating func frame(at timestamp: TimeInterval, nominalDuration: TimeInterval) -> Frame {
            defer { lastTimestamp = timestamp }
            guard let last = lastTimestamp else {
                return Frame(nominalDuration)
            }
            let elapsed = timestamp - last
            guard elapsed > 0, elapsed <= FrameClock.maximumGap else {
                return Frame(nominalDuration)
            }
            return Frame(elapsed)
        }

        mutating func reset() {
            lastTimestamp = nil
        }
    }

    /// Drives the engine from a `CADisplayLink` on the main run loop.
    @MainActor
    final class DisplayLinkDriver: FrameDriver {
        private(set) var displayLink: CADisplayLink?
        private var clock = FrameClock()
        private var onFrame: ((Frame) -> Void)?

        var isRunning: Bool { displayLink != nil }

        var preferredFrameRateRange = Engine.defaultFrameRateRange {
            didSet { displayLink?.preferredFrameRateRange = preferredFrameRateRange }
        }

        func start(onFrame: @escaping (Frame) -> Void) {
            guard displayLink == nil else { return }
            self.onFrame = onFrame
            clock.reset()
            let link = CADisplayLink(target: self, selector: #selector(update(_:)))
            link.preferredFrameRateRange = preferredFrameRateRange
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            onFrame = nil
        }

        @objc private func update(_ link: CADisplayLink) {
            let nominal = link.targetTimestamp - link.timestamp
            let frame = clock.frame(at: link.timestamp, nominalDuration: nominal)
            onFrame?(frame)
        }
    }

    public static let shared = Engine()

    /// The source of frames. Swapping it stops the old driver and, if any
    /// registered action can make progress, hands them to the new one.
    var driver: any FrameDriver = DisplayLinkDriver() {
        willSet { driver.stop() }
        didSet {
            driver.preferredFrameRateRange = preferredFrameRateRange
            refreshDriver()
        }
    }

    private var actions: [Action] = []

    /// How colours are interpolated unless a property says otherwise.
    public var colorInterpolation: ColorInterpolation = .lch

    /// When `true` (the default) and the user has Reduce Motion switched on,
    /// animations snap to their end state. Pauses keep their duration so the
    /// timing of sequences and completion blocks is preserved.
    public var respectsReduceMotion = true

    /// The default ``preferredFrameRateRange``: 120 Hz where the display offers
    /// it, but the system may go as low as 30 Hz to save power or under
    /// thermal pressure.
    public static let defaultFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)

    private static let logger = Logger(subsystem: "Kinieta", category: "Engine")

    /// The frame rates the engine asks the display for while anything is
    /// animating. Changing it takes effect on the next frame, including in
    /// the middle of an animation.
    ///
    /// Animations advance by real elapsed time, so the range changes how
    /// smooth they look and how much power they use, never how long they take.
    /// Lower it for slow fades and colour transitions to save battery, or pass
    /// `CAFrameRateRange.default` to let the system decide. On iPhone, rates
    /// above 60 Hz also need `CADisableMinimumFrameDurationOnPhone` in the
    /// app's Info.plist.
    ///
    /// An invalid range (negative or non-finite rates, a minimum above the
    /// maximum, or a preferred rate outside them) is ignored with a warning.
    public var preferredFrameRateRange = Engine.defaultFrameRateRange {
        didSet {
            guard Self.isValid(preferredFrameRateRange) else {
                let range = preferredFrameRateRange
                Self.logger.warning(
                    "Ignoring invalid frame rate range \(range.minimum, privacy: .public)–\(range.maximum, privacy: .public), preferred \(range.preferred ?? 0, privacy: .public)"
                )
                preferredFrameRateRange = oldValue
                return
            }
            driver.preferredFrameRateRange = preferredFrameRateRange
        }
    }

    /// Whether `range` is one `CADisplayLink` accepts. A zero preferred rate
    /// means "no preference"; `CAFrameRateRange.default` is all zeros.
    static func isValid(_ range: CAFrameRateRange) -> Bool {
        let preferred = range.preferred ?? 0
        let rates = [range.minimum, range.maximum, preferred]
        guard rates.allSatisfy({ $0.isFinite && $0 >= 0 }), range.minimum <= range.maximum else {
            return false
        }
        return preferred == 0 || (range.minimum...range.maximum).contains(preferred)
    }

    /// Injectable for tests; production reads the accessibility setting.
    var isReduceMotionEnabled: () -> Bool = { UIAccessibility.isReduceMotionEnabled }

    var shouldSkipMotion: Bool {
        respectsReduceMotion && isReduceMotionEnabled()
    }

    // MARK: API

    func add(_ action: Action) {
        actions.append(action)
        refreshDriver()
    }

    func remove(_ action: Action) {
        guard let index = actions.firstIndex(where: { $0 === action }) else {
            return
        }
        actions.remove(at: index)
        refreshDriver()
    }

    /// Runs the driver while any action can make progress and stops it when
    /// every action is idle (paused, or waiting forever), so a held timeline
    /// costs no frames. Call it whenever an action is paused, resumed or
    /// cancelled outside a frame.
    func refreshDriver() {
        guard actions.contains(where: { !$0.isIdle }) else {
            driver.stop()
            return
        }
        driver.start { [weak self] frame in
            self?.update(with: frame)
        }
    }

    private func update(with frame: Frame) {
        for action in actions where action.update(frame).isFinished {
            remove(action)
        }
        // An action may have become idle this frame without finishing.
        refreshDriver()
    }
}
#endif
