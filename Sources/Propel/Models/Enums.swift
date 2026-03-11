import Foundation
import SwiftUI

enum Label: String, Codable, CaseIterable, Identifiable, Sendable {
    case blogPost = "Blog Post"
    case conferenceTalk = "Conference Talk"
    case video = "Video"
    case podcast = "Podcast"

    var id: String { rawValue }

    var color: String {
        switch self {
        case .blogPost: "blue"
        case .conferenceTalk: "purple"
        case .video: "red"
        case .podcast: "green"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .blogPost: .blue
        case .conferenceTalk: .purple
        case .video: .red
        case .podcast: .green
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
