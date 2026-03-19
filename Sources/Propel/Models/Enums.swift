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

enum ColumnStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case backlog = "Backlog"
    case inProgress = "In Progress"
    case blocked = "Blocked"
    case completed = "Completed"

    var id: String { rawValue }

    static var defaultOrder: [Self] {
        [.backlog, .inProgress, .blocked, .completed]
    }

    var headerColor: Color {
        switch self {
        case .backlog: .secondary
        case .inProgress: .blue
        case .blocked: .red
        case .completed: .green
        }
    }

    var headerIcon: String {
        switch self {
        case .backlog: "circle.dotted"
        case .inProgress: "circle.lefthalf.filled"
        case .blocked: "xmark.circle.fill"
        case .completed: "checkmark.circle.fill"
        }
    }
}
