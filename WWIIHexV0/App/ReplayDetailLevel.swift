import Foundation

enum ReplayDetailLevel: String, CaseIterable, Codable, Equatable, Identifiable {
    case concise
    case standard
    case full

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .concise:
            return "Concise"
        case .standard:
            return "Standard"
        case .full:
            return "Full"
        }
    }

    var eventLimit: Int {
        switch self {
        case .concise:
            return 25
        case .standard:
            return 60
        case .full:
            return 120
        }
    }

    var directiveLimit: Int {
        switch self {
        case .concise:
            return 4
        case .standard:
            return 8
        case .full:
            return 12
        }
    }

    var showsContextSummary: Bool {
        self != .concise
    }

    var showsRawJSON: Bool {
        self == .full
    }

    var showsRecordIdentifiers: Bool {
        self == .full
    }
}
