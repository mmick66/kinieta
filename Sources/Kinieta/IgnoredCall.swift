// Kinieta — MIT License. See LICENSE.

#if canImport(UIKit) || os(macOS)
import os

/// A chain call that did nothing, such as easing after a `wait`, and where it
/// was made. Reported in debug builds only.
struct IgnoredCall: Equatable, Sendable {
    /// Where the call was made. `nil` for the deprecated `then` property,
    /// which cannot take its caller's location.
    struct Site: Equatable, Sendable {
        let fileID: String
        let line: UInt
    }

    let message: String
    let site: Site?
}

extension Kinieta {

    #if DEBUG
    private static let chainLogger = Logger(subsystem: "Kinieta", category: "Chain")

    /// Receives every ignored call. Logs it by default; tests replace it to
    /// capture the calls instead.
    static var ignoredCallSink: (IgnoredCall) -> Void = { call in
        if let site = call.site {
            chainLogger.warning(
                "\(call.message, privacy: .public) (\(site.fileID, privacy: .public):\(site.line, privacy: .public))")
        } else {
            chainLogger.warning("\(call.message, privacy: .public)")
        }
    }
    #endif

    /// Reports, in debug builds only, that a chain call did nothing.
    /// Release builds neither build the message nor log anything.
    static func ignored(_ message: @autoclosure () -> String, file: StaticString?, line: UInt) {
        #if DEBUG
        let site = file.map { IgnoredCall.Site(fileID: "\($0)", line: line) }
        ignoredCallSink(IgnoredCall(message: message(), site: site))
        #endif
    }
}

extension ActionType {

    /// The chain call that added this step, for warnings.
    var callName: String {
        switch self {
        case .animation:
            return "animate"
        case .pause:
            return "wait"
        case .group:
            return "parallel() or then()"
        case .sequence(let types, _):
            // Only `delay` puts a sequence in a timeline's queue.
            return "delayed " + (types.last?.callName ?? "step")
        case .timelines:
            return "Kinieta.group"
        }
    }
}
#endif
