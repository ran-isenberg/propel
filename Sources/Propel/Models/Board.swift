import Foundation

struct Stage: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var icon: String
    var color: StageColor
    var sortBy: [SortField]
    var sortDirection: SortDirection
    var position: Int
    var isDefaultIntake: Bool
    var isDoneStage: Bool
    var allowsManualCardCreation: Bool

    enum SortDirection: String, Codable, Sendable {
        case ascending
        case descending
    }

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: StageColor,
        sortBy: [SortField] = [.priority, .dueDate],
        sortDirection: SortDirection = .ascending,
        position: Int,
        isDefaultIntake: Bool = false,
        isDoneStage: Bool = false,
        allowsManualCardCreation: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.sortBy = sortBy
        self.sortDirection = sortDirection
        self.position = position
        self.isDefaultIntake = isDefaultIntake
        self.isDoneStage = isDoneStage
        self.allowsManualCardCreation = allowsManualCardCreation ?? !isDoneStage
    }
}

struct Board: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var stages: [Stage]
    var cards: [Card]
    var createdAt: Date
    var updatedAt: Date

    var columns: [Stage] {
        get { stages }
        set { stages = newValue }
    }

    init(
        id: UUID = UUID(),
        name: String = "Propel",
        stages: [Stage]? = nil,
        cards: [Card] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.stages = Self.normalizedStages(stages ?? Self.defaultStages())
        self.cards = Self.normalizedCards(cards, for: self.stages)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case stages
        case cards
        case createdAt
        case updatedAt
        case columns
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Propel"
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt

        if let decodedStages = try container.decodeIfPresent([Stage].self, forKey: .stages) {
            stages = Self.normalizedStages(decodedStages)
            cards = Self.normalizedCards(
                try container.decodeIfPresent([Card].self, forKey: .cards) ?? [],
                for: stages
            )
            return
        }

        let legacyColumns = try container.decodeIfPresent([LegacyColumn].self, forKey: .columns) ?? []
        let migrated = Self.migrateLegacyColumns(legacyColumns)
        stages = Self.normalizedStages(migrated.stages)
        cards = Self.normalizedCards(
            try container.decodeIfPresent([Card].self, forKey: .cards) ?? [],
            for: stages,
            blockedLegacyStageId: migrated.blockedStageId,
            inProgressStageId: migrated.inProgressStageId
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(stages, forKey: .stages)
        try container.encode(cards, forKey: .cards)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    static func defaultStages() -> [Stage] {
        [
            Stage(name: "Backlog", icon: "tray.fill", color: .slate, position: 0, isDefaultIntake: true),
            Stage(name: "In Progress", icon: "arrow.right.circle.fill", color: .blue, position: 1),
            Stage(name: "Completed", icon: "checkmark.circle.fill", color: .green, position: 2, isDoneStage: true)
        ]
    }

    var sortedStages: [Stage] {
        stages.sorted { $0.position < $1.position }
    }

    var defaultIntakeStage: Stage? {
        sortedStages.first(where: \.isDefaultIntake)
    }

    var doneStages: [Stage] {
        sortedStages.filter(\.isDoneStage)
    }

    func stage(withId stageId: UUID) -> Stage? {
        stages.first(where: { $0.id == stageId })
    }

    func cardsForStage(_ stage: Stage) -> [Card] {
        let stageCards = cards.filter { $0.stageId == stage.id }
        return sortCards(stageCards, by: stage.sortBy, direction: stage.sortDirection)
    }

    func cardsForColumn(_ stage: Stage) -> [Card] {
        cardsForStage(stage)
    }

    private func sortCards(_ cards: [Card], by sortFields: [SortField], direction: Stage.SortDirection) -> [Card] {
        cards.sorted { a, b in
            for field in sortFields {
                switch field {
                case .priority:
                    if a.priority != b.priority {
                        return direction == .ascending ? a.priority < b.priority : a.priority > b.priority
                    }
                case .dueDate:
                    switch (a.dueDate, b.dueDate) {
                    case let (aDate?, bDate?):
                        if aDate != bDate {
                            return direction == .ascending ? aDate < bDate : aDate > bDate
                        }
                    case (_?, nil):
                        return direction == .ascending
                    case (nil, _?):
                        return direction != .ascending
                    case (nil, nil):
                        break
                    }
                case .createdAt:
                    if a.createdAt != b.createdAt {
                        return direction == .ascending ? a.createdAt < b.createdAt : a.createdAt > b.createdAt
                    }
                }
            }
            return a.createdAt < b.createdAt
        }
    }

    static func normalizedStages(_ stages: [Stage]) -> [Stage] {
        var normalized = stages.enumerated().map { index, stage in
            var copy = stage
            copy.position = index
            if copy.isDoneStage {
                copy.allowsManualCardCreation = false
            }
            return copy
        }

        if normalized.isEmpty {
            normalized = defaultStages()
        }

        if !normalized.contains(where: \.isDefaultIntake),
           let firstNonDoneIndex = normalized.firstIndex(where: { !$0.isDoneStage })
        {
            normalized[firstNonDoneIndex].isDefaultIntake = true
        }

        for index in normalized.indices where normalized[index].isDoneStage {
            normalized[index].isDefaultIntake = false
        }

        if normalized.filter(\.isDefaultIntake).count > 1 {
            var didKeepDefault = false
            for index in normalized.indices where normalized[index].isDefaultIntake {
                if didKeepDefault {
                    normalized[index].isDefaultIntake = false
                } else {
                    didKeepDefault = true
                }
            }
        }

        if !normalized.contains(where: \.isDefaultIntake),
           let firstNonDoneIndex = normalized.firstIndex(where: { !$0.isDoneStage })
        {
            normalized[firstNonDoneIndex].isDefaultIntake = true
        }

        return normalized
    }

    static func normalizedCards(
        _ cards: [Card],
        for stages: [Stage],
        blockedLegacyStageId: UUID? = nil,
        inProgressStageId: UUID? = nil
    ) -> [Card] {
        let validStageIds = Set(stages.map(\.id))
        let fallbackStageId = stages.first(where: \.isDefaultIntake)?.id ?? stages.first?.id
        let blockedTargetId = inProgressStageId ?? fallbackStageId

        return cards.map { card in
            var copy = card

            if let blockedLegacyStageId, copy.stageId == blockedLegacyStageId {
                copy.stageId = blockedTargetId ?? copy.stageId
                copy.isBlocked = true
            }

            if !validStageIds.contains(copy.stageId), let fallbackStageId {
                copy.stageId = fallbackStageId
            }

            if let stage = stages.first(where: { $0.id == copy.stageId }), stage.isDoneStage {
                copy.completedAt = copy.completedAt ?? copy.updatedAt
                copy.isBlocked = false
            } else {
                copy.completedAt = nil
            }

            return copy
        }
    }

    private static func migrateLegacyColumns(_ columns: [LegacyColumn]) -> LegacyStageMigration {
        let sorted = columns.sorted { $0.position < $1.position }

        var stages: [Stage] = []
        var blockedStageId: UUID?
        var inProgressStageId: UUID?

        for legacy in sorted {
            guard let semantic = legacy.status else {
                let stage = Stage(
                    id: legacy.id,
                    name: legacy.name,
                    icon: "square.fill",
                    color: .slate,
                    sortBy: legacy.sortBy,
                    sortDirection: legacy.sortDirection,
                    position: stages.count
                )
                stages.append(stage)
                continue
            }

            switch semantic {
            case .backlog:
                stages.append(Stage(
                    id: legacy.id,
                    name: legacy.name,
                    icon: "tray.fill",
                    color: .slate,
                    sortBy: legacy.sortBy,
                    sortDirection: legacy.sortDirection,
                    position: stages.count,
                    isDefaultIntake: true
                ))
            case .inProgress:
                inProgressStageId = legacy.id
                stages.append(Stage(
                    id: legacy.id,
                    name: legacy.name,
                    icon: "arrow.right.circle.fill",
                    color: .blue,
                    sortBy: legacy.sortBy,
                    sortDirection: legacy.sortDirection,
                    position: stages.count
                ))
            case .blocked:
                blockedStageId = legacy.id
            case .completed:
                stages.append(Stage(
                    id: legacy.id,
                    name: legacy.name,
                    icon: "checkmark.circle.fill",
                    color: .green,
                    sortBy: legacy.sortBy,
                    sortDirection: legacy.sortDirection,
                    position: stages.count,
                    isDoneStage: true
                ))
            }
        }

        return LegacyStageMigration(
            stages: stages.isEmpty ? defaultStages() : stages,
            blockedStageId: blockedStageId,
            inProgressStageId: inProgressStageId
        )
    }
}

typealias Column = Stage

private struct LegacyColumn: Codable, Sendable {
    let id: UUID
    let name: String
    let status: LegacyColumnStatus?
    let sortBy: [SortField]
    let sortDirection: Stage.SortDirection
    let position: Int
}

private enum LegacyColumnStatus: String, Codable, Sendable {
    case backlog = "Backlog"
    case inProgress = "In Progress"
    case blocked = "Blocked"
    case completed = "Completed"
}

private struct LegacyStageMigration {
    let stages: [Stage]
    let blockedStageId: UUID?
    let inProgressStageId: UUID?
}
