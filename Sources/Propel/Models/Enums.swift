import Foundation
import SwiftUI

// MARK: - Label Definition

struct LabelDefinition: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var colorName: String
    var defaultChecklist: [String]

    init(id: UUID = UUID(), name: String, colorName: String, defaultChecklist: [String] = []) {
        self.id = id
        self.name = name
        self.colorName = colorName
        self.defaultChecklist = defaultChecklist
    }

    var swiftUIColor: Color {
        LabelColor.palette.first { $0.name == colorName }?.color ?? .gray
    }

    // swiftlint:disable force_unwrapping
    private static let blogPostUUID = UUID(uuidString: "A0000001-0000-0000-0000-000000000001")!
    private static let conferenceTalkUUID = UUID(uuidString: "A0000001-0000-0000-0000-000000000002")!
    private static let videoUUID = UUID(uuidString: "A0000001-0000-0000-0000-000000000003")!
    private static let podcastUUID = UUID(uuidString: "A0000001-0000-0000-0000-000000000004")!
    private static let codeUUID = UUID(uuidString: "A0000001-0000-0000-0000-000000000005")!
    private static let articleUUID = UUID(uuidString: "A0000001-0000-0000-0000-000000000006")!
    // swiftlint:enable force_unwrapping

    static let builtInLabels: [Self] = [
        Self(
            id: blogPostUUID,
            name: "Blog Post",
            colorName: "blue",
            defaultChecklist: [
                "Post Structure", "PR", "Merge", "Medium",
                "LinkedIn Newsletter", "GA", "LinkedIn", "X", "Heroes"
            ]
        ),
        Self(id: conferenceTalkUUID, name: "Conference Talk", colorName: "purple"),
        Self(id: videoUUID, name: "Video", colorName: "red"),
        Self(id: podcastUUID, name: "Podcast", colorName: "green"),
        Self(id: codeUUID, name: "Code", colorName: "cyan"),
        Self(id: articleUUID, name: "Article", colorName: "orange")
    ]

    /// Look up a built-in label by its legacy name (used for migration from the old Label enum).
    static func builtIn(named name: String) -> Self? {
        builtInLabels.first { $0.name == name }
    }

    // Convenience accessors for the built-in label IDs
    static var blogPostId: UUID { blogPostUUID }
    static var conferenceTalkId: UUID { conferenceTalkUUID }
    static var videoId: UUID { videoUUID }
    static var podcastId: UUID { podcastUUID }
    static var codeId: UUID { codeUUID }
    static var articleId: UUID { articleUUID }
}

// MARK: - Label Color Palette

struct LabelColor: Identifiable, Sendable {
    let name: String
    let color: Color
    var id: String { name }

    static let palette: [Self] = [
        Self(name: "blue", color: .blue),
        Self(name: "purple", color: .purple),
        Self(name: "red", color: .red),
        Self(name: "green", color: .green),
        Self(name: "cyan", color: .cyan),
        Self(name: "orange", color: .orange),
        Self(name: "yellow", color: .yellow),
        Self(name: "pink", color: .pink),
        Self(name: "brown", color: .brown),
        Self(name: "indigo", color: .indigo),
        Self(name: "mint", color: .mint),
        Self(name: "teal", color: .teal)
    ]
}

enum Priority: String, Codable, CaseIterable, Comparable, Identifiable, Sendable {
    case urgent
    case high
    case normal
    case low

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var sortOrder: Int {
        switch self {
        case .urgent: 0
        case .high: 1
        case .normal: 2
        case .low: 3
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

/// The role a column plays in the board workflow. The three roles below have
/// special behavior (intake for new/recurring cards, blocked for the attention
/// list, done for completion semantics) and their columns cannot be deleted.
enum ColumnRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case intake
    case blocked
    case done

    var id: String { rawValue }
}

/// The palette used to color a board column. Independent from label colors so
/// the two concepts can evolve separately.
enum StageColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case slate
    case blue
    case purple
    case red
    case green
    case orange
    case yellow
    case teal
    case pink
    case indigo

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var swiftUIColor: Color {
        switch self {
        case .slate: .secondary
        case .blue: .blue
        case .purple: .purple
        case .red: .red
        case .green: .green
        case .orange: .orange
        case .yellow: .yellow
        case .teal: .teal
        case .pink: .pink
        case .indigo: .indigo
        }
    }
}
