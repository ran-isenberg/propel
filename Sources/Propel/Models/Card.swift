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
    var stageId: UUID
    var label: Label
    var priority: Priority
    var dueDate: Date?
    var checklist: [ChecklistItem]
    var isRecurring: Bool
    var recurrenceRule: RecurrenceRule?
    var reminder: ReminderOffset
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var isBlocked: Bool

    var columnId: UUID {
        get { stageId }
        set { stageId = newValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        stageId: UUID,
        label: Label,
        priority: Priority = .normal,
        dueDate: Date? = nil,
        checklist: [ChecklistItem] = [],
        isRecurring: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        reminder: ReminderOffset = .none,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        isBlocked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.stageId = stageId
        self.label = label
        self.priority = priority
        self.dueDate = dueDate
        self.checklist = checklist
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.reminder = reminder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.isBlocked = isBlocked
    }

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        columnId: UUID,
        label: Label,
        priority: Priority = .normal,
        dueDate: Date? = nil,
        checklist: [ChecklistItem] = [],
        isRecurring: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        reminder: ReminderOffset = .none,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        isBlocked: Bool = false
    ) {
        self.init(
            id: id,
            title: title,
            description: description,
            stageId: columnId,
            label: label,
            priority: priority,
            dueDate: dueDate,
            checklist: checklist,
            isRecurring: isRecurring,
            recurrenceRule: recurrenceRule,
            reminder: reminder,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt,
            isBlocked: isBlocked
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case stageId
        case columnId
        case label
        case priority
        case dueDate
        case checklist
        case isRecurring
        case recurrenceRule
        case reminder
        case createdAt
        case updatedAt
        case completedAt
        case isBlocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        stageId = try container.decodeIfPresent(UUID.self, forKey: .stageId)
            ?? container.decode(UUID.self, forKey: .columnId)
        label = try container.decode(Label.self, forKey: .label)
        priority = try container.decode(Priority.self, forKey: .priority)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        checklist = try container.decode([ChecklistItem].self, forKey: .checklist)
        isRecurring = try container.decode(Bool.self, forKey: .isRecurring)
        recurrenceRule = try container.decodeIfPresent(RecurrenceRule.self, forKey: .recurrenceRule)
        reminder = try container.decodeIfPresent(ReminderOffset.self, forKey: .reminder) ?? .none
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        isBlocked = try container.decodeIfPresent(Bool.self, forKey: .isBlocked) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(stageId, forKey: .stageId)
        try container.encode(label, forKey: .label)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(checklist, forKey: .checklist)
        try container.encode(isRecurring, forKey: .isRecurring)
        try container.encodeIfPresent(recurrenceRule, forKey: .recurrenceRule)
        try container.encode(reminder, forKey: .reminder)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(isBlocked, forKey: .isBlocked)
    }

    func createRecurringInstance(inStage stageId: UUID) -> Self? {
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
            stageId: stageId,
            label: label,
            priority: priority,
            dueDate: newDueDate,
            checklist: resetChecklist,
            isRecurring: true,
            recurrenceRule: rule,
            reminder: reminder
        )
    }

    func createRecurringInstance(inColumn columnId: UUID) -> Self? {
        createRecurringInstance(inStage: columnId)
    }
}
