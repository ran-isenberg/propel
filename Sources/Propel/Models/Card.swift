import Foundation

struct ChecklistItem: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var position: Int

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, position: Int = 0) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.position = position
    }
}

struct Card: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var description: String
    var columnId: UUID
    var labelId: UUID
    var priority: Priority
    var dueDate: Date?
    var checklist: [ChecklistItem]
    var isRecurring: Bool
    var recurrenceRule: RecurrenceRule?
    var reminder: ReminderOffset
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        columnId: UUID,
        labelId: UUID,
        priority: Priority = .normal,
        dueDate: Date? = nil,
        checklist: [ChecklistItem] = [],
        isRecurring: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        reminder: ReminderOffset = .none,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.columnId = columnId
        self.labelId = labelId
        self.priority = priority
        self.dueDate = dueDate
        self.checklist = checklist
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.reminder = reminder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, columnId, labelId, label, priority, dueDate,
             checklist, isRecurring, recurrenceRule, reminder, createdAt, updatedAt, completedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        columnId = try container.decode(UUID.self, forKey: .columnId)
        // Migration: try new UUID-based labelId first, fall back to old string-based label
        if let uuid = try? container.decode(UUID.self, forKey: .labelId) {
            labelId = uuid
        } else if let legacyName = try? container.decode(String.self, forKey: .label) {
            labelId = LabelDefinition.builtIn(named: legacyName)?.id ?? LabelDefinition.builtInLabels[0].id
        } else {
            labelId = LabelDefinition.builtInLabels[0].id
        }
        priority = try container.decode(Priority.self, forKey: .priority)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        checklist = try container.decode([ChecklistItem].self, forKey: .checklist)
        isRecurring = try container.decode(Bool.self, forKey: .isRecurring)
        recurrenceRule = try container.decodeIfPresent(RecurrenceRule.self, forKey: .recurrenceRule)
        reminder = try container.decodeIfPresent(ReminderOffset.self, forKey: .reminder) ?? .none
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(columnId, forKey: .columnId)
        try container.encode(labelId, forKey: .labelId)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(checklist, forKey: .checklist)
        try container.encode(isRecurring, forKey: .isRecurring)
        try container.encodeIfPresent(recurrenceRule, forKey: .recurrenceRule)
        try container.encode(reminder, forKey: .reminder)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
    }

    /// Create a new recurring instance from this card with reset checklist and new due date.
    func createRecurringInstance(inColumn columnId: UUID) -> Self? {
        guard isRecurring, let rule = recurrenceRule, let currentDueDate = dueDate else {
            return nil
        }
        let newDueDate = rule.nextDueDate(from: currentDueDate)
        let resetChecklist = checklist.map { item in
            ChecklistItem(id: UUID(), title: item.title, isCompleted: false, position: item.position)
        }
        return Self(
            title: title,
            description: description,
            columnId: columnId,
            labelId: labelId,
            priority: priority,
            dueDate: newDueDate,
            checklist: resetChecklist,
            isRecurring: true,
            recurrenceRule: rule,
            reminder: reminder
        )
    }
}
