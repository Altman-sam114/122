import Foundation

enum AICommandPace: String, CaseIterable, Codable, Equatable, Identifiable {
    case instant
    case balanced
    case deliberate

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .instant:
            return "Instant"
        case .balanced:
            return "Balanced"
        case .deliberate:
            return "Deliberate"
        }
    }

    var turnDelay: Duration? {
        switch self {
        case .instant:
            return nil
        case .balanced:
            return .milliseconds(350)
        case .deliberate:
            return .milliseconds(900)
        }
    }

    func turnDelay(reduceMotionEnabled: Bool) -> Duration? {
        reduceMotionEnabled ? nil : turnDelay
    }
}
