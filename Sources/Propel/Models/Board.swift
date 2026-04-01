import Foundation

struct Column: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var status: ColumnStatus
    var sortBy: [SortField]
    var sortDirection: SortDirection
    var position: Int

    enum SortDirection: String, Codable, Sendable {
        case ascending
        case descending
    }

    init(
        id: UUID = UUID(),
        name: String,
        status: ColumnStatus,
        sortBy: [SortField] = [.priority, .dueDate],
        sortDirection: SortDirection = .ascending,
        position: Int
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.sortBy = sortBy
        self.sortDirection = sortDirection
        self.position = position
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

    init(
        id: UUID = UUID(),
        name: String = "Propel",
        columns: [Column]? = nil,
        cards: [Card] = [],
        labels: [LabelDefinition]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.columns = columns ?? Self.defaultColumns()
        self.cards = cards
        self.labels = labels ?? LabelDefinition.builtInLabels
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        columns = try container.decode([Column].self, forKey: .columns)
        cards = try container.decode([Card].self, forKey: .cards)
        labels = try container.decodeIfPresent([LabelDefinition].self, forKey: .labels) ?? LabelDefinition.builtInLabels
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    /// Look up a label definition by ID, with a fallback for orphaned IDs.
    func label(for id: UUID) -> LabelDefinition {
        labels.first { $0.id == id } ?? LabelDefinition(id: id, name: "Unknown", colorName: "gray")
    }

    var sortedLabels: [LabelDefinition] {
        labels.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func defaultColumns() -> [Column] {
        ColumnStatus.defaultOrder.enumerated().map { index, status in
            Column(name: status.rawValue, status: status, position: index)
        }
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
