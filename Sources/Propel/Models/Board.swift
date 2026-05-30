import Foundation

struct Column: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var icon: String
    var color: StageColor
    var sortBy: [SortField]
    var sortDirection: SortDirection
    var position: Int
    /// New cards (manual quick-add and recurring instances) land in this column.
    var isDefaultIntake: Bool
    /// Cards here surface in the attention list and the blocked count.
    var isBlockedStage: Bool
    /// Cards here are considered complete: `completedAt` is set, they are
    /// auto-archived, and excluded from overdue counts.
    var isDoneStage: Bool

    enum SortDirection: String, Codable, Sendable {
        case ascending
        case descending
    }

    /// A column that carries one of the three special workflow roles cannot be
    /// deleted, so the board always has an intake, a blocked, and a done column.
    var isProtected: Bool { isDefaultIntake || isBlockedStage || isDoneStage }

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "circle.dotted",
        color: StageColor = .slate,
        sortBy: [SortField] = [.priority, .dueDate],
        sortDirection: SortDirection = .ascending,
        position: Int,
        isDefaultIntake: Bool = false,
        isBlockedStage: Bool = false,
        isDoneStage: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.sortBy = sortBy
        self.sortDirection = sortDirection
        self.position = position
        self.isDefaultIntake = isDefaultIntake
        self.isBlockedStage = isBlockedStage
        self.isDoneStage = isDoneStage
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, color, sortBy, sortDirection, position
        case isDefaultIntake, isBlockedStage, isDoneStage
        case status // legacy: pre-stages fixed ColumnStatus
    }

    /// Legacy fixed statuses, retained only to migrate boards saved before
    /// columns became user-editable.
    private enum LegacyStatus: String {
        case backlog = "Backlog"
        case inProgress = "In Progress"
        case blocked = "Blocked"
        case ready = "Ready"
        case completed = "Completed"

        var icon: String {
            switch self {
            case .backlog: "tray.fill"
            case .inProgress: "arrow.right.circle.fill"
            case .blocked: "xmark.octagon.fill"
            case .ready: "shippingbox.fill"
            case .completed: "checkmark.circle.fill"
            }
        }

        var color: StageColor {
            switch self {
            case .backlog: .slate
            case .inProgress: .blue
            case .blocked: .red
            case .ready: .purple
            case .completed: .green
            }
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        position = try c.decode(Int.self, forKey: .position)
        sortBy = try c.decodeIfPresent([SortField].self, forKey: .sortBy) ?? [.priority, .dueDate]
        sortDirection = try c.decodeIfPresent(SortDirection.self, forKey: .sortDirection) ?? .ascending

        let legacy = try (c.decodeIfPresent(String.self, forKey: .status)).flatMap(LegacyStatus.init(rawValue:))
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? legacy?.icon ?? "circle.dotted"
        color = try c.decodeIfPresent(StageColor.self, forKey: .color) ?? legacy?.color ?? .slate
        isDefaultIntake = try c.decodeIfPresent(Bool.self, forKey: .isDefaultIntake) ?? (legacy == .backlog)
        isBlockedStage = try c.decodeIfPresent(Bool.self, forKey: .isBlockedStage) ?? (legacy == .blocked)
        isDoneStage = try c.decodeIfPresent(Bool.self, forKey: .isDoneStage) ?? (legacy == .completed)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(icon, forKey: .icon)
        try c.encode(color, forKey: .color)
        try c.encode(sortBy, forKey: .sortBy)
        try c.encode(sortDirection, forKey: .sortDirection)
        try c.encode(position, forKey: .position)
        try c.encode(isDefaultIntake, forKey: .isDefaultIntake)
        try c.encode(isBlockedStage, forKey: .isBlockedStage)
        try c.encode(isDoneStage, forKey: .isDoneStage)
    }
}

struct Board: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var columns: [Column]
    var cards: [Card]
    var labels: [LabelDefinition]
    var createdAt: Date
    var updatedAt: Date
    /// Persisted schema version. Bumped when a one-time data migration must run
    /// against existing boards. Legacy boards decode as `0`; freshly created
    /// boards start at `currentSchemaVersion`.
    var schemaVersion: Int

    /// The schema version this build expects. Loading a board with a lower
    /// version triggers one-time migrations (see `addDefaultChecklistToCards`).
    static let currentSchemaVersion = 1

    init(
        id: UUID = UUID(),
        name: String = "",
        columns: [Column]? = nil,
        cards: [Card] = [],
        labels: [LabelDefinition]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.id = id
        self.name = name
        self.columns = columns ?? Self.defaultColumns()
        self.cards = cards
        self.labels = labels ?? LabelDefinition.builtInLabels
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        columns = try container.decode([Column].self, forKey: .columns)
        cards = try container.decode([Card].self, forKey: .cards)
        let decodedLabels = try container.decodeIfPresent([LabelDefinition].self, forKey: .labels) ?? LabelDefinition.builtInLabels
        // A board must always have at least the default labels, otherwise cards
        // (which require a label) cannot be created on it.
        labels = decodedLabels.isEmpty ? LabelDefinition.builtInLabels : decodedLabels
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        // Legacy boards predate schema versioning; treat them as version 0 so
        // one-time migrations run once and then persist the bumped version.
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0

        // Migration: sync defaultChecklist for built-in labels
        let builtInById = Dictionary(uniqueKeysWithValues: LabelDefinition.builtInLabels.map { ($0.id, $0) })
        for i in labels.indices {
            if let builtIn = builtInById[labels[i].id] {
                labels[i].defaultChecklist = builtIn.defaultChecklist
            }
        }

        // Migration: a board must always have the three protected roles, so any
        // missing role gets a freshly seeded column. Then enforce exactly one
        // intake column and renumber positions.
        Self.ensureProtectedColumns(&columns)
    }

    /// Guarantee exactly one intake, one blocked, and one done column exist,
    /// inserting defaults for any missing role, then normalize positions.
    static func ensureProtectedColumns(_ columns: inout [Column]) {
        columns.sort { $0.position < $1.position }

        if !columns.contains(where: \.isDefaultIntake) {
            if let i = columns.firstIndex(where: { !$0.isDoneStage && !$0.isBlockedStage }) {
                columns[i].isDefaultIntake = true
            } else {
                columns.insert(
                    Column(name: "Backlog", icon: "tray.fill", color: .slate, position: 0, isDefaultIntake: true),
                    at: 0
                )
            }
        }
        if !columns.contains(where: \.isBlockedStage) {
            columns.append(
                Column(name: "Blocked", icon: "xmark.octagon.fill", color: .red, position: columns.count, isBlockedStage: true)
            )
        }
        if !columns.contains(where: \.isDoneStage) {
            columns.append(
                Column(name: "Completed", icon: "checkmark.circle.fill", color: .green, position: columns.count, isDoneStage: true)
            )
        }

        // Keep at most one intake column (first one in order wins).
        var seenIntake = false
        for i in columns.indices where columns[i].isDefaultIntake {
            if seenIntake { columns[i].isDefaultIntake = false } else { seenIntake = true }
        }

        for i in columns.indices {
            columns[i].position = i
        }
    }

    /// Look up a label definition by ID, with a fallback for orphaned IDs.
    func label(for id: UUID) -> LabelDefinition {
        labels.first { $0.id == id } ?? LabelDefinition(id: id, name: "Unknown", colorName: "gray")
    }

    /// The column that fulfills a special workflow role, if present.
    func column(for role: ColumnRole) -> Column? {
        switch role {
        case .intake: columns.first(where: \.isDefaultIntake)
        case .blocked: columns.first(where: \.isBlockedStage)
        case .done: columns.first(where: \.isDoneStage)
        }
    }

    /// Number of cards in the column fulfilling the given role.
    func cardCount(for role: ColumnRole) -> Int {
        guard let column = column(for: role) else { return 0 }
        return cards.count(where: { $0.columnId == column.id })
    }

    /// Cards past their due date that aren't in the done column.
    var overdueCardCount: Int {
        let doneId = column(for: .done)?.id
        let now = Date()
        return cards.count(where: { card in
            guard let due = card.dueDate else { return false }
            if let doneId, card.columnId == doneId { return false }
            return due < now
        })
    }

    var sortedLabels: [LabelDefinition] {
        labels.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func defaultColumns() -> [Column] {
        [
            Column(name: "Backlog", icon: "tray.fill", color: .slate, position: 0, isDefaultIntake: true),
            Column(name: "In Progress", icon: "arrow.right.circle.fill", color: .blue, position: 1),
            Column(name: "Blocked", icon: "xmark.octagon.fill", color: .red, position: 2, isBlockedStage: true),
            Column(name: "Ready", icon: "shippingbox.fill", color: .purple, position: 3),
            Column(name: "Completed", icon: "checkmark.circle.fill", color: .green, position: 4, isDoneStage: true)
        ]
    }

    /// Get cards for a specific column, sorted by the column's sort rules.
    func cardsForColumn(_ column: Column) -> [Card] {
        let columnCards = cards.filter { $0.columnId == column.id }
        return sortCards(columnCards, by: column.sortBy)
    }

    /// Sort cards by priority (urgent first), then by due date (earliest first, nil last).
    private func sortCards(_ cards: [Card], by sortFields: [SortField]) -> [Card] {
        cards.sorted { a, b in
            for field in sortFields {
                switch field {
                case .priority:
                    if a.priority != b.priority {
                        return a.priority < b.priority
                    }
                case .dueDate:
                    switch (a.dueDate, b.dueDate) {
                    case let (aDate?, bDate?):
                        if aDate != bDate {
                            return aDate < bDate
                        }
                    case (_?, nil):
                        return true
                    case (nil, _?):
                        return false
                    case (nil, nil):
                        break
                    }
                case .createdAt:
                    if a.createdAt != b.createdAt {
                        return a.createdAt < b.createdAt
                    }
                }
            }
            return a.createdAt < b.createdAt
        }
    }
}
