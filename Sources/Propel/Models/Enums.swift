import Foundation
import SwiftUI

struct Label: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var color: StageColor

    var rawValue: String { name }

    var swiftUIColor: Color {
        color.swiftUIColor
    }

    static let blogPost = Self(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
        name: "Blog Post",
        color: .blue
    )
    static let conferenceTalk = Self(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
        name: "Conference Talk",
        color: .purple
    )
    static let video = Self(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
        name: "Video",
        color: .red
    )
    static let podcast = Self(
        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID(),
        name: "Podcast",
        color: .green
    )
    static let code = Self(
        id: UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID(),
        name: "Code",
        color: .cyan
    )
    static let article = Self(
        id: UUID(uuidString: "66666666-6666-6666-6666-666666666666") ?? UUID(),
        name: "Article",
        color: .orange
    )

    static var defaults: [Self] {
        [Self.blogPost, Self.conferenceTalk, Self.video, Self.podcast, Self.code, Self.article]
    }

    static var allCases: [Self] {
        Self.defaults
    }

    static var sortedAllCases: [Self] {
        defaults.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func legacy(named name: String) -> Self {
        Self.defaults.first(where: { $0.name == name }) ??
            Self(id: UUID(), name: name, color: .blue)
    }
}

enum Priority: String, Codable, CaseIterable, Comparable, Identifiable, Sendable {
    case urgent
    case normal
    case low

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var sortOrder: Int {
        switch self {
        case .urgent: 0
        case .normal: 1
        case .low: 2
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

enum SortField: String, Codable, CaseIterable, Identifiable, Sendable {
    case priority
    case dueDate
    case createdAt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .priority: "Priority"
        case .dueDate: "Due Date"
        case .createdAt: "Created At"
        }
    }
}

enum Frequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily
    case weekly
    case monthly
    case custom

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

enum ReminderOffset: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case atDueDate
    case fifteenMinutes
    case oneHour
    case oneDay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .atDueDate: "At due date"
        case .fifteenMinutes: "15 minutes before"
        case .oneHour: "1 hour before"
        case .oneDay: "1 day before"
        }
    }

    var offsetSeconds: TimeInterval {
        switch self {
        case .none: 0
        case .atDueDate: 0
        case .fifteenMinutes: -15 * 60
        case .oneHour: -3_600
        case .oneDay: -86_400
        }
    }
}

enum StageColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case slate
    case blue
    case orange
    case red
    case green
    case yellow
    case teal
    case pink
    case purple
    case cyan

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var swiftUIColor: Color {
        switch self {
        case .slate: .secondary
        case .blue: .blue
        case .orange: .orange
        case .red: .red
        case .green: .green
        case .yellow: .yellow
        case .teal: .teal
        case .pink: .pink
        case .purple: .purple
        case .cyan: .cyan
        }
    }
}
