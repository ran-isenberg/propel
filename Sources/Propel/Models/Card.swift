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
    var label: Label
    var priority: Priority
    var dueDate: Date?
    var checklist: [ChecklistItem]
    var isRecurring: Bool
    var recurrenceRule: RecurrenceRule?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

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
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.columnId = columnId
        self.label = label
        self.priority = priority
        self.dueDate = dueDate
        self.checklist = checklist
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
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
            label: label,
            priority: priority,
            dueDate: newDueDate,
            checklist: resetChecklist,
            isRecurring: true,
            recurrenceRule: rule
        )
    }
}
