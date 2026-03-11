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
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Propel",
        columns: [Column]? = nil,
        cards: [Card] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.columns = columns ?? Self.defaultColumns()
        self.cards = cards
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
