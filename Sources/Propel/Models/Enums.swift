import Foundation
import SwiftUI

enum Label: String, Codable, CaseIterable, Identifiable, Sendable {
    case blogPost = "Blog Post"
    case conferenceTalk = "Conference Talk"
    case video = "Video"
    case podcast = "Podcast"
    case code = "Code"
    case article = "Article"

    var id: String { rawValue }

    static var sortedAllCases: [Self] {
        allCases.sorted { $0.rawValue.localizedCaseInsensitiveCompare($1.rawValue) == .orderedAscending }
    }

    var color: String {
        switch self {
        case .blogPost: "blue"
        case .conferenceTalk: "purple"
        case .video: "red"
        case .podcast: "green"
        case .code: "cyan"
        case .article: "orange"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .blogPost: .blue
        case .conferenceTalk: .purple
        case .video: .red
        case .podcast: .green
        case .code: .cyan
        case .article: .orange
        }
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
        }
    }
}
