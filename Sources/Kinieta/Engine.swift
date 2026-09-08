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

import UIKit

@MainActor
public final class Engine {

    /// One tick of the engine clock.
    struct Frame: Sendable {
        /// Display-link timestamp of this frame, in seconds.
        var timestamp: TimeInterval
        /// Time elapsed since the previous frame, in seconds. Actions advance by this amount.
        var duration: TimeInterval
        init(_ timestamp: TimeInterval, _ duration: TimeInterval) {
            self.timestamp = timestamp
            self.duration  = duration
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
                return Frame(timestamp, nominalDuration)
            }
            let elapsed = timestamp - last
            guard elapsed > 0, elapsed <= FrameClock.maximumGap else {
                return Frame(timestamp, nominalDuration)
            }
            return Frame(timestamp, elapsed)
        }

        mutating func reset() {
            lastTimestamp = nil
        }
    }

    @MainActor
    final class DisplayLink {
        private var displayLink: CADisplayLink?
        private var clock = FrameClock()
        private var onUpdate: ((Frame) -> Void)?

        func pause() {
            displayLink?.isPaused = true
        }

        func resume() {
            displayLink?.isPaused = false
        }

        func start(onUpdate: @escaping (Frame) -> Void) {
            guard displayLink == nil else { return }
            self.onUpdate = onUpdate
            clock.reset()
            let link = CADisplayLink(target: self, selector: #selector(update(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            onUpdate = nil
        }

        @objc private func update(_ link: CADisplayLink) {
            let nominal = link.targetTimestamp - link.timestamp
            let frame = clock.frame(at: link.timestamp, nominalDuration: nominal)
            onUpdate?(frame)
        }
    }

    public static let shared = Engine()

    let displayLink = Engine.DisplayLink()

    private var actions: [Action] = []

    /// How colours are interpolated unless a property says otherwise.
    public var colorInterpolation: ColorInterpolation = .lch

    /// When `true` (the default) and the user has Reduce Motion switched on,
    /// animations snap to their end state. Pauses keep their duration so the
    /// timing of sequences and completion blocks is preserved.
    public var respectsReduceMotion = true

    /// Injectable for tests; production reads the accessibility setting.
    var isReduceMotionEnabled: () -> Bool = { UIAccessibility.isReduceMotionEnabled }

    var shouldSkipMotion: Bool {
        respectsReduceMotion && isReduceMotionEnabled()
    }

    // MARK: API

    func add(_ action: Action) {
        actions.append(action)
        displayLink.start { [weak self] frame in
            self?.update(with: frame)
        }
    }

    func remove(_ action: Action) {
        guard let index = actions.firstIndex(where: { $0 === action }) else {
            return
        }
        actions.remove(at: index)
        if actions.isEmpty {
            displayLink.stop()
        }
    }

    private func update(with frame: Frame) {
        for action in actions {
            switch action.update(frame) {
            case .running:  continue
            case .finished: remove(action)
            }
        }
    }
}
