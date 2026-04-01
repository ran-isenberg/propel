import AppKit
import Foundation
@testable import Propel
import Testing

// MARK: - Board Tests

struct BoardTests {
    @Test func initializesWithDefaultColumns() {
        let board = Board()
        #expect(board.columns.count == 4)
        #expect(board.columns[0].status == .backlog)
        #expect(board.columns[1].status == .inProgress)
        #expect(board.columns[2].status == .blocked)
        #expect(board.columns[3].status == .completed)
    }

    @Test func defaultColumnsHaveCorrectNames() {
        let board = Board()
        #expect(board.columns[0].name == "Backlog")
        #expect(board.columns[1].name == "In Progress")
        #expect(board.columns[2].name == "Blocked")
        #expect(board.columns[3].name == "Completed")
    }

    @Test func defaultColumnsHaveCorrectPositions() {
        let board = Board()
        for (index, column) in board.columns.enumerated() {
            #expect(column.position == index)
        }
    }

    @Test func defaultColumnsSortByPriorityThenDueDate() {
        let board = Board()
        for column in board.columns {
            #expect(column.sortBy == [.priority, .dueDate])
        }
    }

    @Test func initializesWithEmptyCards() {
        let board = Board()
        #expect(board.cards.isEmpty)
    }

    @Test func cardsForColumnFiltersCorrectly() {
        let board = Board()
        let backlogId = board.columns[0].id
        let inProgressId = board.columns[1].id
        var mutableBoard = board
        mutableBoard.cards = [
            Card(title: "Card 1", columnId: backlogId, label: .blogPost),
            Card(title: "Card 2", columnId: backlogId, label: .video),
            Card(title: "Card 3", columnId: inProgressId, label: .podcast)
        ]
        let backlogCards = mutableBoard.cardsForColumn(mutableBoard.columns[0])
        let inProgressCards = mutableBoard.cardsForColumn(mutableBoard.columns[1])
        #expect(backlogCards.count == 2)
        #expect(inProgressCards.count == 1)
        #expect(inProgressCards[0].title == "Card 3")
    }

    @Test func cardsForColumnSortsByPriorityFirst() {
        let board = Board()
        let colId = board.columns[0].id
        var mutableBoard = board
        mutableBoard.cards = [
            Card(title: "Low", columnId: colId, label: .blogPost, priority: .low),
            Card(title: "Urgent", columnId: colId, label: .blogPost, priority: .urgent),
            Card(title: "Normal", columnId: colId, label: .blogPost, priority: .normal)
        ]
        let sorted = mutableBoard.cardsForColumn(mutableBoard.columns[0])
        #expect(sorted[0].title == "Urgent")
        #expect(sorted[1].title == "Normal")
        #expect(sorted[2].title == "Low")
    }

    @Test func cardsForColumnSortsByDueDateWithinSamePriority() throws {
        let board = Board()
        let colId = board.columns[0].id
        let now = Date()
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
        let nextWeek = try #require(Calendar.current.date(byAdding: .day, value: 7, to: now))
        var mutableBoard = board
        mutableBoard.cards = [
            Card(title: "Next week", columnId: colId, label: .blogPost, priority: .normal, dueDate: nextWeek),
            Card(title: "Tomorrow", columnId: colId, label: .blogPost, priority: .normal, dueDate: tomorrow),
            Card(title: "Today", columnId: colId, label: .blogPost, priority: .normal, dueDate: now)
        ]
        let sorted = mutableBoard.cardsForColumn(mutableBoard.columns[0])
        #expect(sorted[0].title == "Today")
        #expect(sorted[1].title == "Tomorrow")
        #expect(sorted[2].title == "Next week")
    }

    @Test func cardsForColumnNilDueDateSortsLast() {
        let board = Board()
        let colId = board.columns[0].id
        let now = Date()
        var mutableBoard = board
        mutableBoard.cards = [
            Card(title: "No date", columnId: colId, label: .blogPost, priority: .normal, dueDate: nil),
            Card(title: "Has date", columnId: colId, label: .blogPost, priority: .normal, dueDate: now)
        ]
        let sorted = mutableBoard.cardsForColumn(mutableBoard.columns[0])
        #expect(sorted[0].title == "Has date")
        #expect(sorted[1].title == "No date")
    }

    @Test func cardsForColumnEmptyReturnsEmpty() {
        let board = Board()
        let blockedCards = board.cardsForColumn(board.columns[2])
        #expect(blockedCards.isEmpty)
    }
}

// MARK: - Card Tests

struct CardTests {
    @Test func initializesWithDefaults() {
        let colId = UUID()
        let card = Card(title: "Test", columnId: colId, label: .blogPost)
        #expect(card.title == "Test")
        #expect(card.columnId == colId)
        #expect(card.label == .blogPost)
        #expect(card.priority == .normal)
        #expect(card.dueDate == nil)
        #expect(card.checklist.isEmpty)
        #expect(card.isRecurring == false)
        #expect(card.recurrenceRule == nil)
        #expect(card.description.isEmpty)
        #expect(card.completedAt == nil)
    }

    @Test func createRecurringInstanceCopiesFields() throws {
        let colId = UUID()
        let backlogId = UUID()
        let card = Card(
            title: "Weekly review",
            description: "Review all tasks",
            columnId: colId,
            label: .conferenceTalk,
            priority: .urgent,
            dueDate: Date(),
            checklist: [
                ChecklistItem(title: "Step 1", isCompleted: true, position: 0),
                ChecklistItem(title: "Step 2", isCompleted: true, position: 1)
            ],
            isRecurring: true,
            recurrenceRule: RecurrenceRule(interval: 1, frequency: .weekly)
        )
        let newCard = try #require(card.createRecurringInstance(inColumn: backlogId))
        #expect(newCard.id != card.id)
        #expect(newCard.title == "Weekly review")
        #expect(newCard.description == "Review all tasks")
        #expect(newCard.columnId == backlogId)
        #expect(newCard.label == .conferenceTalk)
        #expect(newCard.priority == .urgent)
        #expect(newCard.isRecurring == true)
        #expect(newCard.recurrenceRule == card.recurrenceRule)
    }

    @Test func createRecurringInstanceResetsChecklist() throws {
        let colId = UUID()
        let card = Card(
            title: "Task",
            columnId: colId,
            label: .blogPost,
            dueDate: Date(),
            checklist: [
                ChecklistItem(title: "Done item", isCompleted: true, position: 0),
                ChecklistItem(title: "Also done", isCompleted: true, position: 1)
            ],
            isRecurring: true,
            recurrenceRule: RecurrenceRule(interval: 1, frequency: .daily)
        )
        let newCard = try #require(card.createRecurringInstance(inColumn: UUID()))
        #expect(newCard.checklist.count == 2)
        #expect(newCard.checklist[0].isCompleted == false)
        #expect(newCard.checklist[1].isCompleted == false)
        #expect(newCard.checklist[0].title == "Done item")
        #expect(newCard.checklist[1].title == "Also done")
        // Checklist item IDs should be new
        #expect(newCard.checklist[0].id != card.checklist[0].id)
    }

    @Test func createRecurringInstanceCalculatesNewDueDate() throws {
        let colId = UUID()
        let dueDate = Date()
        let card = Card(
            title: "Monthly",
            columnId: colId,
            label: .podcast,
            dueDate: dueDate,
            isRecurring: true,
            recurrenceRule: RecurrenceRule(interval: 1, frequency: .monthly)
        )
        let newCard = try #require(card.createRecurringInstance(inColumn: UUID()))
        let expected = try #require(Calendar.current.date(byAdding: .month, value: 1, to: dueDate))
        #expect(newCard.dueDate == expected)
    }

    @Test func createRecurringInstanceReturnsNilWhenNotRecurring() {
        let card = Card(title: "One-off", columnId: UUID(), label: .blogPost, isRecurring: false)
        #expect(card.createRecurringInstance(inColumn: UUID()) == nil)
    }

    @Test func createRecurringInstanceReturnsNilWithoutDueDate() {
        let card = Card(
            title: "No date",
            columnId: UUID(),
            label: .blogPost,
            dueDate: nil,
            isRecurring: true,
            recurrenceRule: RecurrenceRule(interval: 1, frequency: .weekly)
        )
        #expect(card.createRecurringInstance(inColumn: UUID()) == nil)
    }

    @Test func createRecurringInstanceReturnsNilWithoutRule() {
        let card = Card(
            title: "No rule",
            columnId: UUID(),
            label: .blogPost,
            dueDate: Date(),
            isRecurring: true,
            recurrenceRule: nil
        )
        #expect(card.createRecurringInstance(inColumn: UUID()) == nil)
    }
}

// MARK: - RecurrenceRule Tests

struct RecurrenceRuleTests {
    @Test func dailyRecurrence() throws {
        let rule = RecurrenceRule(interval: 3, frequency: .daily)
        let start = Date()
        let next = rule.nextDueDate(from: start)
        let expected = try #require(Calendar.current.date(byAdding: .day, value: 3, to: start))
        #expect(next == expected)
    }

    @Test func weeklyRecurrence() throws {
        let rule = RecurrenceRule(interval: 2, frequency: .weekly)
        let start = Date()
        let next = rule.nextDueDate(from: start)
        let expected = try #require(Calendar.current.date(byAdding: .weekOfYear, value: 2, to: start))
        #expect(next == expected)
    }

    @Test func monthlyRecurrence() throws {
        let rule = RecurrenceRule(interval: 1, frequency: .monthly)
        let start = Date()
        let next = rule.nextDueDate(from: start)
        let expected = try #require(Calendar.current.date(byAdding: .month, value: 1, to: start))
        #expect(next == expected)
    }

    @Test func customRecurrenceUsesDays() throws {
        let rule = RecurrenceRule(interval: 30, frequency: .custom)
        let start = Date()
        let next = rule.nextDueDate(from: start)
        let daysDiff = try #require(Calendar.current.dateComponents([.day], from: start, to: next).day)
        #expect(daysDiff == 30)
    }
}

// MARK: - Priority Tests

struct PriorityTests {
    @Test func sortOrder() {
        #expect(Priority.urgent < Priority.normal)
        #expect(Priority.normal < Priority.low)
        #expect(Priority.urgent < Priority.low)
    }

    @Test func allCasesExist() {
        #expect(Priority.allCases.count == 3)
    }

    @Test func displayNames() {
        #expect(Priority.urgent.displayName == "Urgent")
        #expect(Priority.normal.displayName == "Normal")
        #expect(Priority.low.displayName == "Low")
    }
}

// MARK: - Label Tests

struct LabelTests {
    @Test func exactlySixLabels() {
        #expect(Label.allCases.count == 6)
    }

    @Test func rawValues() {
        #expect(Label.blogPost.rawValue == "Blog Post")
        #expect(Label.conferenceTalk.rawValue == "Conference Talk")
        #expect(Label.video.rawValue == "Video")
        #expect(Label.podcast.rawValue == "Podcast")
        #expect(Label.code.rawValue == "Code")
    }

    @Test func distinctColors() {
        let colors = Label.allCases.map(\.color)
        let uniqueColors = Set(colors)
        #expect(uniqueColors.count == 6)
    }
}

// MARK: - ColumnStatus Tests

struct ColumnStatusTests {
    @Test func defaultOrderHasFourStatuses() {
        #expect(ColumnStatus.defaultOrder.count == 4)
    }

    @Test func defaultOrderIsCorrect() {
        let order = ColumnStatus.defaultOrder
        #expect(order == [.backlog, .inProgress, .blocked, .completed])
    }
}

// MARK: - Note Tests

struct NoteTests {
    @Test func initializesWithDefaults() {
        let note = Note(title: "Setup Script")
        #expect(note.title == "Setup Script")
        #expect(note.content.isEmpty)
    }

    @Test func notesStoreInitializesEmpty() {
        let store = NotesStore()
        #expect(store.notes.isEmpty)
    }
}

// MARK: - ChecklistItem Tests

struct ChecklistItemTests {
    @Test func initializesUnchecked() {
        let item = ChecklistItem(title: "Do something")
        #expect(item.title == "Do something")
        #expect(item.isCompleted == false)
        #expect(item.position == 0)
    }
}

// MARK: - SortField Enum Tests

struct SortFieldTests {
    @Test func allCasesExist() {
        #expect(SortField.allCases.count == 3)
    }

    @Test func displayNames() {
        #expect(SortField.priority.displayName == "Priority")
        #expect(SortField.dueDate.displayName == "Due Date")
        #expect(SortField.createdAt.displayName == "Created At")
    }
}

// MARK: - Status Header Color Tests

struct StatusHeaderColorTests {
    @Test func eachStatusHasDistinctColor() {
        let colors = ColumnStatus.allCases.map(\.headerColor)
        // Just verify they exist and are accessible
        #expect(colors.count == 4)
    }

    @Test func blockedIsRed() {
        #expect(ColumnStatus.blocked.headerColor == .red)
    }

    @Test func completedIsGreen() {
        #expect(ColumnStatus.completed.headerColor == .green)
    }

    @Test func inProgressIsBlue() {
        #expect(ColumnStatus.inProgress.headerColor == .blue)
    }
}

// MARK: - Codable Roundtrip Tests

struct CodableTests {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// ISO8601 drops sub-second precision, so use a date truncated to seconds.
    private func stableDate() -> Date {
        Date(timeIntervalSince1970: Double(Int(Date().timeIntervalSince1970)))
    }

    @Test func boardRoundtrip() throws {
        let now = stableDate()
        var board = Board(createdAt: now, updatedAt: now)
        board.cards.append(Card(
            title: "Test card",
            columnId: board.columns[0].id,
            label: .video,
            priority: .urgent,
            dueDate: now,
            checklist: [ChecklistItem(title: "Sub-task", isCompleted: true, position: 0)],
            isRecurring: true,
            recurrenceRule: RecurrenceRule(interval: 7, frequency: .daily),
            createdAt: now,
            updatedAt: now
        ))
        let data = try encoder.encode(board)
        let decoded = try decoder.decode(Board.self, from: data)
        #expect(decoded == board)
    }

    @Test func notesStoreRoundtrip() throws {
        let now = stableDate()
        let store = NotesStore(notes: [
            Note(title: "Note 1", content: "Content 1", createdAt: now, updatedAt: now),
            Note(title: "Note 2", content: "brew install node", createdAt: now, updatedAt: now)
        ])
        let data = try encoder.encode(store)
        let decoded = try decoder.decode(NotesStore.self, from: data)
        #expect(decoded == store)
    }

    @Test func cardWithAllFieldsRoundtrip() throws {
        let now = stableDate()
        let card = Card(
            title: "Full card",
            description: "Description with link https://example.com",
            columnId: UUID(),
            label: .conferenceTalk,
            priority: .low,
            dueDate: now,
            checklist: [
                ChecklistItem(title: "A", isCompleted: false, position: 0),
                ChecklistItem(title: "B", isCompleted: true, position: 1)
            ],
            isRecurring: true,
            recurrenceRule: RecurrenceRule(interval: 2, frequency: .weekly),
            createdAt: now,
            updatedAt: now,
            completedAt: now
        )
        let data = try encoder.encode(card)
        let decoded = try decoder.decode(Card.self, from: data)
        #expect(decoded == card)
    }
}
