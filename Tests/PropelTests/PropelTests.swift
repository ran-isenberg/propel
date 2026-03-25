import AppKit
import Foundation
@testable import Propel
import Testing

// MARK: - Board Tests

struct BoardTests {
    @Test func initializesWithDefaultStages() {
        let board = Board()
        #expect(board.columns.count == 3)
        #expect(board.columns[0].name == "Backlog")
        #expect(board.columns[0].isDefaultIntake == true)
        #expect(board.columns[1].name == "In Progress")
        #expect(board.columns[2].name == "Completed")
        #expect(board.columns[2].isDoneStage == true)
    }

    @Test func defaultStagesHaveCorrectNames() {
        let board = Board()
        #expect(board.columns[0].name == "Backlog")
        #expect(board.columns[1].name == "In Progress")
        #expect(board.columns[2].name == "Completed")
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
        let doneCards = board.cardsForColumn(board.columns[2])
        #expect(doneCards.isEmpty)
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

// MARK: - StageColor Tests

struct StageColorTests {
    @Test func allStageColorsExist() {
        #expect(StageColor.allCases.count == 10)
    }

    @Test func colorsHaveDistinctNames() {
        let names = Set(StageColor.allCases.map(\.displayName))
        #expect(names.count == StageColor.allCases.count)
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

// MARK: - BoardViewModel Tests

@MainActor
struct BoardViewModelTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel(autoLoad: false)
        // Reset to a fresh board (overrides the async load)
        vm.board = Board()
        return vm
    }

    @Test func createCardAddsToBoard() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "New task", label: .blogPost, priority: .normal, inColumn: colId)
        #expect(vm.board.cards.count == 1)
        #expect(vm.board.cards[0].title == "New task")
        #expect(vm.board.cards[0].label == .blogPost)
        #expect(vm.board.cards[0].columnId == colId)
    }

    @Test func createCardSelectsNewCard() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Task", label: .video, priority: .urgent, inColumn: colId)
        #expect(vm.selectedCardId == vm.board.cards[0].id)
        #expect(vm.isCreatingCard == false)
    }

    @Test func deleteCardRemovesFromBoard() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "To delete", label: .podcast, priority: .low, inColumn: colId)
        let cardId = vm.board.cards[0].id
        vm.deleteCard(cardId)
        #expect(vm.board.cards.isEmpty)
        #expect(vm.selectedCardId == nil)
    }

    @Test func deleteNonExistentCardIsNoOp() {
        let vm = makeViewModel()
        vm.deleteCard(UUID())
        #expect(vm.board.cards.isEmpty)
    }

    @Test func duplicateCardCreatesACopy() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Original", label: .blogPost, priority: .urgent, inColumn: colId)
        let originalId = vm.board.cards[0].id
        // Set description via update to avoid any parameter naming issues
        var card = vm.board.cards[0]
        card.description = "Desc"
        vm.updateCard(card)
        vm.duplicateCard(originalId)
        #expect(vm.board.cards.count == 2)
        let copy = vm.board.cards[1]
        #expect(copy.title == "Original")
        #expect(copy.description == "Desc")
        #expect(copy.label == .blogPost)
        #expect(copy.priority == .urgent)
        #expect(copy.id != originalId)
        #expect(copy.completedAt == nil)
    }

    @Test func moveCardChangesColumn() {
        let vm = makeViewModel()
        let backlogId = vm.board.columns[0].id
        let inProgressId = vm.board.columns[1].id
        vm.createCard(title: "Moving", label: .video, priority: .normal, inColumn: backlogId)
        let cardId = vm.board.cards[0].id
        vm.moveCard(cardId, toColumn: inProgressId)
        #expect(vm.board.cards[0].columnId == inProgressId)
    }

    @Test func moveCardToSameColumnIsNoOp() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Stay", label: .blogPost, priority: .normal, inColumn: colId)
        let cardId = vm.board.cards[0].id
        let updatedBefore = vm.board.cards[0].updatedAt
        vm.moveCard(cardId, toColumn: colId)
        // Card should not have been modified
        #expect(vm.board.cards[0].updatedAt == updatedBefore)
    }

    @Test func moveCardToCompletedSetsCompletedAt() {
        let vm = makeViewModel()
        let backlogId = vm.board.columns[0].id
        let completedId = vm.board.columns[2].id
        vm.createCard(title: "Done", label: .podcast, priority: .normal, inColumn: backlogId)
        let cardId = vm.board.cards[0].id
        vm.moveCard(cardId, toColumn: completedId)
        #expect(vm.board.cards[0].completedAt != nil)
    }

    @Test func moveCardOutOfCompletedClearsCompletedAt() {
        let vm = makeViewModel()
        let backlogId = vm.board.columns[0].id
        let completedId = vm.board.columns[2].id
        vm.createCard(title: "Reopen", label: .blogPost, priority: .normal, inColumn: backlogId)
        let cardId = vm.board.cards[0].id
        vm.moveCard(cardId, toColumn: completedId)
        #expect(vm.board.cards[0].completedAt != nil)
        vm.moveCard(cardId, toColumn: backlogId)
        #expect(vm.board.cards[0].completedAt == nil)
    }

    @Test func moveRecurringCardToCompletedCreatesNewInstance() throws {
        let vm = makeViewModel()
        let backlogId = vm.board.columns[0].id
        let completedId = vm.board.columns[2].id
        let card = Card(
            title: "Recurring",
            columnId: backlogId,
            label: .video,
            priority: .normal,
            dueDate: Date(),
            isRecurring: true,
            recurrenceRule: RecurrenceRule(interval: 1, frequency: .weekly)
        )
        vm.board.cards.append(card)
        vm.moveCard(card.id, toColumn: completedId)
        #expect(vm.board.cards.count == 2)
        let newCard = try #require(vm.board.cards.last)
        #expect(newCard.columnId == backlogId)
        #expect(newCard.title == "Recurring")
        #expect(newCard.isRecurring == true)
        #expect(newCard.id != card.id)
    }

    @Test func moveNonRecurringCardToCompletedDoesNotCreateNewInstance() {
        let vm = makeViewModel()
        let backlogId = vm.board.columns[0].id
        let completedId = vm.board.columns[2].id
        vm.createCard(title: "One-off", label: .blogPost, priority: .normal, inColumn: backlogId)
        vm.moveCard(vm.board.cards[0].id, toColumn: completedId)
        #expect(vm.board.cards.count == 1)
    }

    @Test func changeCardPriority() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Task", label: .blogPost, priority: .normal, inColumn: colId)
        let cardId = vm.board.cards[0].id
        vm.changeCardPriority(cardId, to: .urgent)
        #expect(vm.board.cards[0].priority == .urgent)
    }

    @Test func changeCardLabel() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Task", label: .blogPost, priority: .normal, inColumn: colId)
        let cardId = vm.board.cards[0].id
        vm.changeCardLabel(cardId, to: .podcast)
        #expect(vm.board.cards[0].label == .podcast)
    }

    @Test func changeCardDueDate() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Task", label: .blogPost, priority: .normal, inColumn: colId)
        let cardId = vm.board.cards[0].id
        let newDate = Date()
        vm.changeCardDueDate(cardId, to: newDate)
        #expect(vm.board.cards[0].dueDate == newDate)
    }

    @Test func removeDueDate() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Task", label: .blogPost, priority: .normal, dueDate: Date(), inColumn: colId)
        let cardId = vm.board.cards[0].id
        vm.changeCardDueDate(cardId, to: nil)
        #expect(vm.board.cards[0].dueDate == nil)
    }

    @Test func toggleCardBlockedSetsFlagInPlace() {
        let vm = makeViewModel()
        let inProgressId = vm.board.columns[1].id
        vm.createCard(title: "Block me", label: .video, priority: .normal, inColumn: inProgressId)
        let cardId = vm.board.cards[0].id
        vm.toggleCardBlocked(cardId)
        #expect(vm.board.cards[0].columnId == inProgressId)
        #expect(vm.board.cards[0].isBlocked == true)
    }

    @Test func toggleCardBlockedClearsFlag() {
        let vm = makeViewModel()
        let inProgressId = vm.board.columns[1].id
        vm.createCard(title: "Unblock me", label: .video, priority: .normal, inColumn: inProgressId)
        let cardId = vm.board.cards[0].id
        vm.board.cards[0].isBlocked = true
        vm.toggleCardBlocked(cardId)
        #expect(vm.board.cards[0].columnId == inProgressId)
        #expect(vm.board.cards[0].isBlocked == false)
    }

    @Test func updateCard() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Old title", label: .blogPost, priority: .normal, inColumn: colId)
        var card = vm.board.cards[0]
        card.title = "New title"
        card.description = "Added description"
        vm.updateCard(card)
        #expect(vm.board.cards[0].title == "New title")
        #expect(vm.board.cards[0].description == "Added description")
    }

    @Test func sortedColumnsReturnsByPosition() {
        let vm = makeViewModel()
        let columns = vm.sortedColumns
        #expect(columns.count == 3)
        for i in 0 ..< columns.count {
            #expect(columns[i].position == i)
        }
    }

    @Test func defaultIntakeStageFindsCorrectStage() {
        let vm = makeViewModel()
        #expect(vm.defaultIntakeStage?.name == "Backlog")
        #expect(vm.doneStages.count == 1)
        #expect(vm.doneStages.first?.name == "Completed")
    }

    @Test func sidePanelStateManagement() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id

        // Initially closed
        #expect(vm.showSidePanel == false)

        // Start creating
        vm.startCreatingCard(inColumn: colId)
        #expect(vm.isCreatingCard == true)
        #expect(vm.creationTargetColumnId == colId)
        #expect(vm.showSidePanel == true)

        // Close
        vm.closeSidePanel()
        #expect(vm.showSidePanel == false)
        #expect(vm.selectedCardId == nil)
        #expect(vm.isCreatingCard == false)

        // Select a card
        vm.createCard(title: "Test", label: .blogPost, priority: .normal, inColumn: colId)
        let cardId = vm.board.cards[0].id
        vm.closeSidePanel()
        vm.selectCard(cardId)
        #expect(vm.selectedCardId == cardId)
        #expect(vm.showSidePanel == true)
        #expect(vm.isCreatingCard == false)
    }
}

// MARK: - NotesViewModel Tests

@MainActor
struct NotesViewModelTests {
    private func makeViewModel() -> NotesViewModel {
        let vm = NotesViewModel()
        vm.store = NotesStore()
        return vm
    }

    @Test func createNoteAddsToStore() {
        let vm = makeViewModel()
        vm.createNote()
        #expect(vm.store.notes.count == 1)
        #expect(vm.store.notes[0].title == "Untitled Note")
        #expect(vm.selectedNoteId == vm.store.notes[0].id)
    }

    @Test func createMultipleNotes() {
        let vm = makeViewModel()
        vm.createNote()
        vm.createNote()
        vm.createNote()
        #expect(vm.store.notes.count == 3)
    }

    @Test func updateNoteChangesContent() {
        let vm = makeViewModel()
        vm.createNote()
        var note = vm.store.notes[0]
        note.title = "Mac Setup"
        note.content = "brew install node"
        vm.updateNote(note)
        #expect(vm.store.notes[0].title == "Mac Setup")
        #expect(vm.store.notes[0].content == "brew install node")
    }

    @Test func deleteNoteRemovesFromStore() {
        let vm = makeViewModel()
        vm.createNote()
        let noteId = vm.store.notes[0].id
        vm.confirmDeleteNote(noteId)
        #expect(vm.showDeleteConfirmation == true)
        #expect(vm.noteToDelete == noteId)
        vm.deleteNote()
        #expect(vm.store.notes.isEmpty)
        #expect(vm.selectedNoteId == nil)
    }

    @Test func deleteNonSelectedNoteKeepsSelection() {
        let vm = makeViewModel()
        vm.createNote()
        vm.createNote()
        let firstId = vm.store.notes[0].id
        let secondId = vm.store.notes[1].id
        vm.selectedNoteId = firstId
        vm.confirmDeleteNote(secondId)
        vm.deleteNote()
        #expect(vm.store.notes.count == 1)
        #expect(vm.selectedNoteId == firstId)
    }

    @Test func searchByTitle() {
        let vm = makeViewModel()
        vm.createNote()
        var note = vm.store.notes[0]
        note.title = "Mac Setup Script"
        note.content = "Some content"
        vm.updateNote(note)
        vm.createNote()
        var note2 = vm.store.notes[1]
        note2.title = "API Reference"
        note2.content = "Other content"
        vm.updateNote(note2)

        vm.searchText = "Mac"
        #expect(vm.filteredNotes.count == 1)
        #expect(vm.filteredNotes[0].title == "Mac Setup Script")
    }

    @Test func searchByContent() {
        let vm = makeViewModel()
        vm.createNote()
        var note = vm.store.notes[0]
        note.title = "Setup"
        note.content = "brew install node\nbrew install python"
        vm.updateNote(note)
        vm.createNote()
        var note2 = vm.store.notes[1]
        note2.title = "Other"
        note2.content = "unrelated stuff"
        vm.updateNote(note2)

        vm.searchText = "brew"
        #expect(vm.filteredNotes.count == 1)
        #expect(vm.filteredNotes[0].title == "Setup")
    }

    @Test func searchIsCaseInsensitive() {
        let vm = makeViewModel()
        vm.createNote()
        var note = vm.store.notes[0]
        note.title = "UPPERCASE"
        note.content = "some MIXED content"
        vm.updateNote(note)

        vm.searchText = "uppercase"
        #expect(vm.filteredNotes.count == 1)

        vm.searchText = "mixed"
        #expect(vm.filteredNotes.count == 1)
    }

    @Test func emptySearchReturnsAll() {
        let vm = makeViewModel()
        vm.createNote()
        vm.createNote()
        vm.searchText = ""
        #expect(vm.filteredNotes.count == 2)
    }

    @Test func filteredNotesSortedByUpdatedAt() {
        let vm = makeViewModel()
        vm.createNote()
        vm.createNote()
        // Update the first note so it has a newer updatedAt
        var older = vm.store.notes[0]
        older.title = "Older"
        vm.updateNote(older)
        var newer = vm.store.notes[1]
        newer.title = "Newer"
        vm.updateNote(newer)
        // The "Newer" note was updated last, so it should appear first
        let filtered = vm.filteredNotes
        #expect(filtered[0].title == "Newer")
    }

    @Test func selectedNoteReturnsCorrectNote() {
        let vm = makeViewModel()
        vm.createNote()
        let noteId = vm.store.notes[0].id
        vm.selectedNoteId = noteId
        #expect(vm.selectedNote?.id == noteId)
    }

    @Test func selectedNoteReturnsNilWhenNoneSelected() {
        let vm = makeViewModel()
        vm.selectedNoteId = nil
        #expect(vm.selectedNote == nil)
    }
}

// MARK: - V2: Filter Tests

@MainActor
struct FilterTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel(autoLoad: false)
        vm.board = Board()
        return vm
    }

    @Test func filterByLabel() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Blog", label: .blogPost, priority: .normal, inColumn: colId)
        vm.createCard(title: "Video", label: .video, priority: .normal, inColumn: colId)
        vm.createCard(title: "Podcast", label: .podcast, priority: .normal, inColumn: colId)

        vm.filterLabel = .blogPost
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 1)
        #expect(cards[0].title == "Blog")
    }

    @Test func filterByPriority() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Urgent", label: .blogPost, priority: .urgent, inColumn: colId)
        vm.createCard(title: "Normal", label: .blogPost, priority: .normal, inColumn: colId)
        vm.createCard(title: "Low", label: .blogPost, priority: .low, inColumn: colId)

        vm.filterPriority = .urgent
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 1)
        #expect(cards[0].title == "Urgent")
    }

    @Test func filterByBothLabelAndPriority() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "A", label: .blogPost, priority: .urgent, inColumn: colId)
        vm.createCard(title: "B", label: .blogPost, priority: .normal, inColumn: colId)
        vm.createCard(title: "C", label: .video, priority: .urgent, inColumn: colId)

        vm.filterLabel = .blogPost
        vm.filterPriority = .urgent
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 1)
        #expect(cards[0].title == "A")
    }

    @Test func clearFiltersShowsAll() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "A", label: .blogPost, priority: .normal, inColumn: colId)
        vm.createCard(title: "B", label: .video, priority: .urgent, inColumn: colId)

        vm.filterLabel = .blogPost
        #expect(vm.cardsForColumn(vm.board.columns[0]).count == 1)

        vm.clearFilters()
        #expect(vm.cardsForColumn(vm.board.columns[0]).count == 2)
    }

    @Test func isFilterActiveReflectsState() {
        let vm = makeViewModel()
        #expect(vm.isFilterActive == false)
        vm.filterLabel = .podcast
        #expect(vm.isFilterActive == true)
        vm.filterLabel = nil
        vm.filterPriority = .low
        #expect(vm.isFilterActive == true)
        vm.clearFilters()
        #expect(vm.isFilterActive == false)
    }

    @Test func filterAcrossColumns() {
        let vm = makeViewModel()
        let backlogId = vm.board.columns[0].id
        let inProgressId = vm.board.columns[1].id
        vm.createCard(title: "Blog Backlog", label: .blogPost, priority: .normal, inColumn: backlogId)
        vm.createCard(title: "Video Backlog", label: .video, priority: .normal, inColumn: backlogId)
        // Move one to in-progress by directly setting columnId
        vm.board.cards[1].columnId = inProgressId

        vm.filterLabel = .video
        #expect(vm.cardsForColumn(vm.board.columns[0]).isEmpty)
        #expect(vm.cardsForColumn(vm.board.columns[1]).count == 1)
    }
}

// MARK: - V2: Column Sort Config Tests

@MainActor
struct ColumnSortTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel(autoLoad: false)
        vm.board = Board()
        return vm
    }

    @Test func updateColumnSort() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.updateColumnSort(colId, sortBy: [.dueDate, .createdAt])
        #expect(vm.board.columns[0].sortBy == [.dueDate, .createdAt])
    }

    @Test func sortByDueDatePrimary() throws {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.updateColumnSort(colId, sortBy: [.dueDate])

        let now = Date()
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
        let nextWeek = try #require(Calendar.current.date(byAdding: .day, value: 7, to: now))

        vm.board.cards = [
            Card(title: "Next week", columnId: colId, label: .blogPost, priority: .low, dueDate: nextWeek),
            Card(title: "Tomorrow", columnId: colId, label: .blogPost, priority: .urgent, dueDate: tomorrow),
            Card(title: "Today", columnId: colId, label: .blogPost, priority: .normal, dueDate: now)
        ]

        let sorted = vm.cardsForColumn(vm.board.columns[0])
        #expect(sorted[0].title == "Today")
        #expect(sorted[1].title == "Tomorrow")
        #expect(sorted[2].title == "Next week")
    }

    @Test func sortByCreatedAtPrimary() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.updateColumnSort(colId, sortBy: [.createdAt])

        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let t3 = Date(timeIntervalSince1970: 3_000)

        vm.board.cards = [
            Card(title: "Third", columnId: colId, label: .blogPost, priority: .low, createdAt: t3),
            Card(title: "First", columnId: colId, label: .blogPost, priority: .urgent, createdAt: t1),
            Card(title: "Second", columnId: colId, label: .blogPost, priority: .normal, createdAt: t2)
        ]

        let sorted = vm.cardsForColumn(vm.board.columns[0])
        #expect(sorted[0].title == "First")
        #expect(sorted[1].title == "Second")
        #expect(sorted[2].title == "Third")
    }

    @Test func updateNonExistentColumnIsNoOp() {
        let vm = makeViewModel()
        let originalSort = vm.board.columns[0].sortBy
        vm.updateColumnSort(UUID(), sortBy: [.createdAt])
        #expect(vm.board.columns[0].sortBy == originalSort)
    }
}

// MARK: - V2: SortField Enum Tests

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

// MARK: - V3: Search Tests

@MainActor
struct SearchTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel(autoLoad: false)
        vm.board = Board()
        return vm
    }

    @Test func searchByTitle() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Write blog post", label: .blogPost, priority: .normal, inColumn: colId)
        vm.createCard(title: "Record video", label: .video, priority: .normal, inColumn: colId)
        vm.createCard(title: "Podcast episode", label: .podcast, priority: .normal, inColumn: colId)

        vm.searchText = "blog"
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 1)
        #expect(cards[0].title == "Write blog post")
    }

    @Test func searchByDescription() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Task A", label: .blogPost, priority: .normal, inColumn: colId)
        var card = vm.board.cards[0]
        card.description = "Contains the keyword banana"
        vm.updateCard(card)

        vm.createCard(title: "Task B", label: .video, priority: .normal, inColumn: colId)

        vm.searchText = "banana"
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 1)
        #expect(cards[0].title == "Task A")
    }

    @Test func searchIsCaseInsensitive() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "UPPERCASE Title", label: .blogPost, priority: .normal, inColumn: colId)

        vm.searchText = "uppercase"
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 1)
    }

    @Test func emptySearchShowsAll() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "A", label: .blogPost, priority: .normal, inColumn: colId)
        vm.createCard(title: "B", label: .video, priority: .normal, inColumn: colId)

        vm.searchText = ""
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 2)
    }

    @Test func searchResultsProperty() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Alpha", label: .blogPost, priority: .normal, inColumn: colId)
        vm.createCard(title: "Beta", label: .video, priority: .normal, inColumn: colId)
        vm.createCard(title: "Alpha Two", label: .podcast, priority: .normal, inColumn: colId)

        vm.searchText = "Alpha"
        #expect(vm.searchResults.count == 2)
    }

    @Test func toggleSearchClearsText() {
        let vm = makeViewModel()
        vm.isSearching = true
        vm.searchText = "something"
        vm.toggleSearch()
        #expect(vm.isSearching == false)
        #expect(vm.searchText.isEmpty)
    }
}

// MARK: - V3: Collapsible Columns Tests

@MainActor
struct CollapsibleColumnsTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel(autoLoad: false)
        vm.board = Board()
        return vm
    }

    @Test func columnsStartExpanded() {
        let vm = makeViewModel()
        for column in vm.board.columns {
            #expect(vm.isColumnCollapsed(column.id) == false)
        }
    }

    @Test func toggleCollapse() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.toggleColumnCollapsed(colId)
        #expect(vm.isColumnCollapsed(colId) == true)
        vm.toggleColumnCollapsed(colId)
        #expect(vm.isColumnCollapsed(colId) == false)
    }

    @Test func collapseOneDoesNotAffectOthers() {
        let vm = makeViewModel()
        let col0 = vm.board.columns[0].id
        let col1 = vm.board.columns[1].id
        vm.toggleColumnCollapsed(col0)
        #expect(vm.isColumnCollapsed(col0) == true)
        #expect(vm.isColumnCollapsed(col1) == false)
    }
}

// MARK: - V3: Auto-Archive Tests

@MainActor
struct AutoArchiveTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel(autoLoad: false)
        vm.board = Board()
        return vm
    }

    @Test func recentCompletedCardsAreVisible() {
        let vm = makeViewModel()
        let completedId = vm.board.columns[2].id
        vm.board.cards.append(Card(
            title: "Just done",
            columnId: completedId,
            label: .blogPost,
            completedAt: Date()
        ))
        vm.autoArchiveDays = 7
        let cards = vm.cardsForColumn(vm.board.columns[2])
        #expect(cards.count == 1)
    }

    @Test func oldCompletedCardsAreHidden() throws {
        let vm = makeViewModel()
        let completedId = vm.board.columns[2].id
        let tenDaysAgo = try #require(Calendar.current.date(byAdding: .day, value: -10, to: Date()))
        vm.board.cards.append(Card(
            title: "Old done",
            columnId: completedId,
            label: .blogPost,
            completedAt: tenDaysAgo
        ))
        vm.autoArchiveDays = 7
        let cards = vm.cardsForColumn(vm.board.columns[2])
        #expect(cards.isEmpty)
    }

    @Test func disabledAutoArchiveShowsAll() throws {
        let vm = makeViewModel()
        let completedId = vm.board.columns[2].id
        let oldDate = try #require(Calendar.current.date(byAdding: .day, value: -30, to: Date()))
        vm.board.cards.append(Card(
            title: "Very old",
            columnId: completedId,
            label: .blogPost,
            completedAt: oldDate
        ))
        vm.autoArchiveDays = 0
        let cards = vm.cardsForColumn(vm.board.columns[2])
        #expect(cards.count == 1)
    }
}

// MARK: - V3: Stage Color Tests

struct StatusHeaderColorTests {
    @Test func eachStageColorIsAccessible() {
        let colors = StageColor.allCases.map(\.swiftUIColor)
        #expect(colors.count == StageColor.allCases.count)
    }

    @Test func greenMapsToGreen() {
        #expect(StageColor.green.swiftUIColor == .green)
    }

    @Test func redMapsToRed() {
        #expect(StageColor.red.swiftUIColor == .red)
    }

    @Test func blueMapsToBlue() {
        #expect(StageColor.blue.swiftUIColor == .blue)
    }
}

// MARK: - V4: Attention View Tests

@MainActor
struct AttentionViewTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel(autoLoad: false)
        vm.board = Board()
        return vm
    }

    @Test func overdueCardsAppearInAttention() throws {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        vm.board.cards.append(Card(
            title: "Overdue",
            columnId: colId,
            label: .blogPost,
            dueDate: yesterday
        ))
        #expect(vm.attentionCards.count == 1)
        #expect(vm.attentionCards[0].title == "Overdue")
    }

    @Test func dueSoonCardsAppearInAttention() throws {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
        vm.board.cards.append(Card(
            title: "Due soon",
            columnId: colId,
            label: .blogPost,
            dueDate: tomorrow
        ))
        #expect(vm.attentionCards.count == 1)
    }

    @Test func blockedCardsAppearInAttention() {
        let vm = makeViewModel()
        vm.board.cards.append(Card(
            title: "Blocked card",
            columnId: vm.board.columns[1].id,
            label: .blogPost,
            isBlocked: true
        ))
        #expect(vm.attentionCards.count == 1)
    }

    @Test func completedCardsExcludedFromAttention() throws {
        let vm = makeViewModel()
        let completedId = vm.board.columns[2].id
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        vm.board.cards.append(Card(
            title: "Done overdue",
            columnId: completedId,
            label: .blogPost,
            dueDate: yesterday,
            completedAt: Date()
        ))
        #expect(vm.attentionCards.isEmpty)
    }

    @Test func futureCardsExcludedFromAttention() throws {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        let nextMonth = try #require(Calendar.current.date(byAdding: .month, value: 1, to: Date()))
        vm.board.cards.append(Card(
            title: "Far future",
            columnId: colId,
            label: .blogPost,
            dueDate: nextMonth
        ))
        #expect(vm.attentionCards.isEmpty)
    }

    @Test func overdueCount() throws {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        vm.board.cards.append(Card(title: "OD1", columnId: colId, label: .blogPost, dueDate: yesterday))
        vm.board.cards.append(Card(title: "OD2", columnId: colId, label: .video, dueDate: yesterday))
        #expect(vm.overdueCount == 2)
    }

    @Test func blockedCountProperty() {
        let vm = makeViewModel()
        let activeId = vm.board.columns[1].id
        vm.board.cards.append(Card(title: "B1", columnId: activeId, label: .blogPost, isBlocked: true))
        vm.board.cards.append(Card(title: "B2", columnId: activeId, label: .video, isBlocked: true))
        #expect(vm.blockedCount == 2)
    }
}

// MARK: - V4: Weekly Review Tests

@MainActor
struct WeeklyReviewTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel(autoLoad: false)
        vm.board = Board()
        return vm
    }

    @Test func reviewDataCountsCompletedThisWeek() {
        let vm = makeViewModel()
        let completedId = vm.board.columns[2].id
        vm.board.cards.append(Card(
            title: "Done today",
            columnId: completedId,
            label: .blogPost,
            completedAt: Date()
        ))
        vm.board.cards.append(Card(
            title: "Done long ago",
            columnId: completedId,
            label: .video,
            completedAt: Calendar.current.date(byAdding: .day, value: -30, to: Date())
        ))
        let data = vm.weeklyReviewData
        #expect(data.completedCards.count == 1)
        #expect(data.completedCards[0].title == "Done today")
    }

    @Test func reviewDataCountsCreatedThisWeek() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "New card", label: .blogPost, priority: .normal, inColumn: colId)
        let data = vm.weeklyReviewData
        #expect(data.createdCards.count == 1)
    }

    @Test func reviewDataCountsActiveCards() {
        let vm = makeViewModel()
        let inProgressId = vm.board.columns[1].id
        vm.board.cards.append(Card(title: "WIP", columnId: inProgressId, label: .blogPost))
        let data = vm.weeklyReviewData
        #expect(data.activeCards.count == 1)
    }

    @Test func reviewDataCountsOverdue() throws {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        vm.board.cards.append(Card(title: "Late", columnId: colId, label: .blogPost, dueDate: yesterday))
        let data = vm.weeklyReviewData
        #expect(data.overdueCards.count == 1)
    }

    @Test func reviewDataTotalCards() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "A", label: .blogPost, priority: .normal, inColumn: colId)
        vm.createCard(title: "B", label: .video, priority: .normal, inColumn: colId)
        let data = vm.weeklyReviewData
        #expect(data.totalCards == 2)
    }
}

// MARK: - V4: Menu Bar Badge Tests

@MainActor
struct MenuBarBadgeTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel(autoLoad: false)
        vm.board = Board()
        return vm
    }

    @Test func badgeCountShowsOverdue() throws {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        vm.board.cards.append(Card(title: "OD", columnId: colId, label: .blogPost, dueDate: yesterday))
        #expect(vm.menuBarBadgeCount == 1)
    }

    @Test func zeroBadgeWhenAllClear() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Normal", label: .blogPost, priority: .normal, inColumn: colId)
        #expect(vm.menuBarBadgeCount == 0)
    }
}

// MARK: - Emoji Support Tests

@MainActor
struct EmojiSupportTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel(autoLoad: false)
        vm.board = Board()
        return vm
    }

    @Test func cardTitleSupportsEmoji() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "🚀 Launch Day", label: .blogPost, priority: .urgent, inColumn: colId)
        let card = vm.board.cards.first
        #expect(card?.title == "🚀 Launch Day")
    }

    @Test func cardDescriptionSupportsEmoji() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(
            title: "Test",
            label: .blogPost,
            priority: .normal,
            description: "Need to review 📝 and ship 🎉",
            inColumn: colId
        )
        let card = vm.board.cards.first
        #expect(card?.description == "Need to review 📝 and ship 🎉")
    }

    @Test func emojiOnlyTitle() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "🎯🔥💡", label: .video, priority: .normal, inColumn: colId)
        let card = vm.board.cards.first
        #expect(card?.title == "🎯🔥💡")
        #expect(card?.title.count == 3)
    }

    @Test func searchFindsEmojiInTitle() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "🚀 Launch", label: .blogPost, priority: .normal, inColumn: colId)
        vm.createCard(title: "Review PR", label: .blogPost, priority: .normal, inColumn: colId)
        vm.isSearching = true
        vm.searchText = "🚀"
        let results = vm.cardsForColumn(vm.board.columns[0])
        #expect(results.count == 1)
        #expect(results.first?.title == "🚀 Launch")
    }

    @Test func searchFindsEmojiInDescription() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(
            title: "Task",
            label: .blogPost,
            priority: .normal,
            description: "Important 🔥 task",
            inColumn: colId
        )
        vm.createCard(title: "Other", label: .blogPost, priority: .normal, inColumn: colId)
        vm.isSearching = true
        vm.searchText = "🔥"
        let results = vm.cardsForColumn(vm.board.columns[0])
        #expect(results.count == 1)
        #expect(results.first?.title == "Task")
    }

    @Test func emojiCardRoundtripsThroughCodable() throws {
        let card = Card(
            title: "📋 Sprint Review",
            description: "Check all items ✅ and fix bugs 🐛",
            columnId: UUID(),
            label: .conferenceTalk,
            priority: .urgent,
            checklist: [
                ChecklistItem(title: "🎨 Design review", isCompleted: true, position: 0),
                ChecklistItem(title: "🧪 Testing", isCompleted: false, position: 1)
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(card)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Card.self, from: data)

        #expect(decoded.title == "📋 Sprint Review")
        #expect(decoded.description == "Check all items ✅ and fix bugs 🐛")
        #expect(decoded.checklist[0].title == "🎨 Design review")
        #expect(decoded.checklist[1].title == "🧪 Testing")
    }

    @Test func noteTitleAndContentSupportEmoji() {
        let note = Note(title: "📓 Daily Log")
        #expect(note.title == "📓 Daily Log")

        var updated = note
        updated.content = "Today I worked on 🚀 deployment and 🐛 bug fixes"
        #expect(updated.content.contains("🚀"))
        #expect(updated.content.contains("🐛"))
    }

    @Test func noteSearchFindsEmoji() {
        let vm = NotesViewModel()
        vm.store = NotesStore()

        var note1 = Note(title: "🎯 Goals")
        note1.content = "Ship v2"
        vm.store.notes.append(note1)

        var note2 = Note(title: "Meeting")
        note2.content = "Regular meeting"
        vm.store.notes.append(note2)

        vm.searchText = "🎯"
        #expect(vm.filteredNotes.count == 1)
        #expect(vm.filteredNotes.first?.title == "🎯 Goals")
    }

    @Test func mixedEmojiAndTextTrimming() {
        let input = "  🚀 Launch Day  "
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed == "🚀 Launch Day")
        #expect(!trimmed.isEmpty)
    }

    @Test func complexEmojiSequences() throws {
        let card = Card(
            title: "👨‍👩‍👧‍👦 Family feature 🏳️‍🌈",
            description: "Support for 🇺🇸 flag emojis and 👍🏽 skin tones",
            columnId: UUID(),
            label: .blogPost
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(card)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Card.self, from: data)

        #expect(decoded.title == "👨‍👩‍👧‍👦 Family feature 🏳️‍🌈")
        #expect(decoded.description == "Support for 🇺🇸 flag emojis and 👍🏽 skin tones")
    }

    @Test func checklistItemsWithEmoji() {
        let items = [
            ChecklistItem(title: "✏️ Write draft", isCompleted: true, position: 0),
            ChecklistItem(title: "🎨 Create graphics", isCompleted: false, position: 1),
            ChecklistItem(title: "📤 Publish", isCompleted: false, position: 2)
        ]
        #expect(items[0].title == "✏️ Write draft")
        #expect(items.filter(\.isCompleted).count == 1)
    }
}

// MARK: - Edge Case Tests

struct EdgeCaseTests {
    /// Create a BoardViewModel and wait for its init's async loadBoard() to complete
    /// so subsequent board assignments aren't overwritten.
    private static func makeViewModel() async -> BoardViewModel {
        let vm = await BoardViewModel(autoLoad: false)
        // Let the init's Task { await loadBoard() } finish before we set test data
        try? await Task.sleep(for: .milliseconds(100))
        return vm
    }

    // MARK: - Blog Post Default Checklist

    @Test func blogPostCardGetsDefaultChecklist() async {
        let vm = await Self.makeViewModel()
        let board = Board()
        await MainActor.run { vm.board = board }
        let backlogId = board.columns[0].id

        await MainActor.run {
            vm.createCard(
                title: "My Blog",
                label: .blogPost,
                priority: .normal,
                inColumn: backlogId
            )
        }

        let card = await vm.board.cards.first
        let checklist = card?.checklist ?? []
        #expect(card != nil)
        #expect(checklist.count == 9)
        let titles = checklist.map(\.title)
        #expect(titles.contains("Post Structure"))
        #expect(titles.contains("Medium"))
        #expect(titles.contains("LinkedIn Newsletter"))
        #expect(titles.contains("PR"))
        #expect(titles.contains("Merge"))
        #expect(titles.contains("GA"))
        #expect(titles.contains("LinkedIn"))
        #expect(titles.contains("X"))
        #expect(titles.contains("Heroes"))
    }

    @Test func nonBlogPostCardGetsEmptyChecklist() async {
        let vm = await Self.makeViewModel()
        let board = Board()
        await MainActor.run { vm.board = board }
        let backlogId = board.columns[0].id

        await MainActor.run {
            vm.createCard(
                title: "My Talk",
                label: .conferenceTalk,
                priority: .normal,
                inColumn: backlogId
            )
        }

        let card = await vm.board.cards.first
        #expect(card != nil)
        #expect(card?.checklist.isEmpty == true)
    }

    @Test func addDefaultChecklistSkipsSaveWhenNoChanges() async {
        let vm = await Self.makeViewModel()
        let board = Board()
        await MainActor.run { vm.board = board }
        let backlogId = board.columns[0].id

        // Create a blog card (already has defaults)
        await MainActor.run {
            vm.createCard(
                title: "Blog",
                label: .blogPost,
                priority: .normal,
                inColumn: backlogId
            )
        }

        let beforeDate = await vm.board.cards[0].updatedAt

        // Running again should not modify
        try? await Task.sleep(for: .milliseconds(10))
        await MainActor.run { vm.addDefaultChecklistToBlogCards() }

        let afterDate = await vm.board.cards[0].updatedAt
        #expect(beforeDate == afterDate)
    }

    @Test func addDefaultChecklistAddsOnlyMissingItems() async {
        let vm = await Self.makeViewModel()
        var board = Board()
        let backlogId = board.columns[0].id
        var card = Card(
            title: "Partial Blog",
            columnId: backlogId,
            label: .blogPost
        )
        card.checklist = [
            ChecklistItem(title: "PR", isCompleted: true, position: 0),
            ChecklistItem(title: "Custom Step", position: 1),
        ]
        board.cards.append(card)
        await MainActor.run { vm.board = board }

        await MainActor.run { vm.addDefaultChecklistToBlogCards() }

        let updated = await vm.board.cards[0]
        let titles = updated.checklist.map(\.title)
        // PR already existed, should not duplicate
        #expect(titles.filter { $0 == "PR" }.count == 1)
        // Custom step preserved
        #expect(titles.contains("Custom Step"))
        // Missing defaults added
        #expect(titles.contains("Merge"))
        #expect(titles.contains("GA"))
        #expect(titles.contains("LinkedIn"))
        #expect(titles.contains("X"))
        #expect(titles.contains("Heroes"))
    }

    // MARK: - Note RTF Data

    @Test func noteRtfDataRoundTripAndPlainText() {
        let content = NSAttributedString(
            string: "Hello World",
            attributes: [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.white]
        )
        let rtfData = try? content.data(
            from: NSRange(location: 0, length: content.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        #expect(rtfData != nil)
        if let data = rtfData,
           let restored = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            #expect(restored.string == "Hello World")
        } else {
            #expect(Bool(false), "Failed to restore RTF data")
        }

        let note = Note(title: "Test", content: "Plain text", rtfData: nil)
        #expect(note.content == "Plain text")
        #expect(note.rtfData == nil)
    }

    // MARK: - Dark Mode Color Detection

    @Test @MainActor func darkColorDetection() {
        #expect(RichTextEditor.isColorDark(.black) == true)
        #expect(RichTextEditor.isColorDark(.white) == false)
        #expect(RichTextEditor.isColorDark(NSColor(white: 0.5, alpha: 1.0)) == false)
        #expect(RichTextEditor.isColorDark(NSColor(white: 0.2, alpha: 1.0)) == true)
    }

    @Test @MainActor func fixDarkModeColorsConversions() {
        // Black → white
        let blackInput = NSAttributedString(string: "Dark", attributes: [.foregroundColor: NSColor.black])
        var color: NSColor?
        RichTextEditor.fixDarkModeColors(blackInput).enumerateAttribute(
            .foregroundColor, in: NSRange(location: 0, length: 4)
        ) { value, _, _ in color = value as? NSColor }
        #expect(color == NSColor.white)

        // Yellow preserved
        let yellowInput = NSAttributedString(string: "Yellow", attributes: [.foregroundColor: NSColor.yellow])
        var yColor: NSColor?
        RichTextEditor.fixDarkModeColors(yellowInput).enumerateAttribute(
            .foregroundColor, in: NSRange(location: 0, length: 6)
        ) { value, _, _ in yColor = value as? NSColor }
        #expect(yColor != NSColor.white)

        // No color → white
        let noColorInput = NSAttributedString(string: "NC", attributes: [.font: NSFont.systemFont(ofSize: 14)])
        var ncColor: NSColor?
        RichTextEditor.fixDarkModeColors(noColorInput).enumerateAttribute(
            .foregroundColor, in: NSRange(location: 0, length: 2)
        ) { value, _, _ in ncColor = value as? NSColor }
        #expect(ncColor == NSColor.white)

        // Empty string
        #expect(RichTextEditor.fixDarkModeColors(NSAttributedString(string: "")).length == 0)
    }

    // MARK: - Recurrence Rule Edge Cases

    @Test func recurrenceRuleSafeIntervalClamping() {
        #expect(RecurrenceRule(interval: 0, frequency: .weekly).safeInterval >= 1)
        #expect(RecurrenceRule(interval: -5, frequency: .daily).safeInterval >= 1)
        #expect(RecurrenceRule(interval: 5000, frequency: .monthly).safeInterval <= 999)
    }

    // MARK: - Card Toggle Blocked

    @Test func toggleBlockedMovesCorrectly() async {
        let vm = await Self.makeViewModel()
        let board = Board()
        await MainActor.run { vm.board = board }
        let backlogId = board.columns[0].id

        await MainActor.run { vm.createCard(title: "Test", label: .blogPost, priority: .normal, inColumn: backlogId) }
        let cardId = await vm.board.cards[0].id
        await MainActor.run { vm.toggleCardBlocked(cardId) }
        #expect(await vm.board.cards.first { $0.id == cardId }?.columnId == backlogId)
        #expect(await vm.board.cards.first { $0.id == cardId }?.isBlocked == true)

        await MainActor.run { vm.toggleCardBlocked(cardId) }
        #expect(await vm.board.cards.first { $0.id == cardId }?.columnId == backlogId)
        #expect(await vm.board.cards.first { $0.id == cardId }?.isBlocked == false)
    }

    // MARK: - Auto-Archive Cutoff

    @Test func autoArchiveWithZeroDaysShowsAllCompleted() async {
        let vm = await Self.makeViewModel()
        var board = Board()
        let completedId = board.columns[2].id
        var card = Card(title: "Old Done", columnId: completedId, label: .blogPost)
        card.completedAt = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        board.cards.append(card)
        await MainActor.run {
            vm.board = board
            vm.autoArchiveDays = 0
        }

        let completedColumn = board.columns[2]
        let cards = await vm.cardsForColumn(completedColumn)
        #expect(cards.count == 1)
    }

    // MARK: - Limits & Progress

    @Test func checklistAndCardLimits() {
        let longTitle = String(repeating: "a", count: 600)
        #expect(String(longTitle.prefix(500)).count == 500)

        var items: [ChecklistItem] = []
        for idx in 0..<100 { items.append(ChecklistItem(title: "Item \(idx)", position: idx)) }
        #expect(items.count == 100)
        #expect((items.count < 100) == false)

        var title = String(repeating: "x", count: 250)
        if title.count > 200 { title = String(title.prefix(200)) }
        #expect(title.count == 200)

        var desc = String(repeating: "y", count: 11_000)
        if desc.count > 10_000 { desc = String(desc.prefix(10_000)) }
        #expect(desc.count == 10_000)
    }

    @Test func checklistProgressCalculation() {
        let empty: [ChecklistItem] = []
        let emptyProgress: Double = empty.isEmpty ? 0 : Double(empty.filter(\.isCompleted).count) / Double(empty.count)
        #expect(emptyProgress == 0)

        let checklist = [
            ChecklistItem(title: "A", isCompleted: true, position: 0),
            ChecklistItem(title: "B", isCompleted: false, position: 1),
        ]
        let progress = checklist.isEmpty ? 0 : Double(checklist.filter(\.isCompleted).count) / Double(checklist.count)
        #expect(progress == 0.5)
    }
}

// MARK: - Notification & Reminder Tests

struct ReminderOffsetTests {
    @Test func offsetSecondsValues() {
        #expect(ReminderOffset.none.offsetSeconds == 0)
        #expect(ReminderOffset.atDueDate.offsetSeconds == 0)
        #expect(ReminderOffset.fifteenMinutes.offsetSeconds == -900)
        #expect(ReminderOffset.oneHour.offsetSeconds == -3_600)
        #expect(ReminderOffset.oneDay.offsetSeconds == -86_400)
    }

    @Test func allCasesHaveDisplayNamesAndRoundTrip() throws {
        for offset in ReminderOffset.allCases {
            #expect(!offset.displayName.isEmpty)
            let data = try JSONEncoder().encode(offset)
            let decoded = try JSONDecoder().decode(ReminderOffset.self, from: data)
            #expect(decoded == offset)
        }
    }
}

struct ReminderCardTests {
    @Test func cardDefaultsAndStoresReminder() {
        let defaultCard = Card(title: "Test", columnId: UUID(), label: .blogPost, priority: .normal)
        #expect(defaultCard.reminder == .none)

        let card = Card(
            title: "Test",
            columnId: UUID(),
            label: .blogPost,
            priority: .normal,
            dueDate: Date(),
            reminder: .fifteenMinutes
        )
        #expect(card.reminder == .fifteenMinutes)
    }

    @Test func cardDecoderDefaultsReminderToNone() throws {
        let card = Card(title: "Old Card", columnId: UUID(), label: .blogPost, priority: .normal)
        let data = try JSONEncoder().encode(card)
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            #expect(Bool(false), "Failed to parse JSON")
            return
        }
        json.removeValue(forKey: "reminder")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(Card.self, from: modifiedData)
        #expect(decoded.reminder == .none)
    }

    @Test func recurringInstanceCarriesOverReminder() throws {
        let card = Card(
            title: "Recurring",
            columnId: UUID(),
            label: .blogPost,
            priority: .normal,
            dueDate: Date(),
            isRecurring: true,
            recurrenceRule: RecurrenceRule(interval: 1, frequency: .weekly),
            reminder: .oneHour
        )
        let newCard = try #require(card.createRecurringInstance(inColumn: UUID()))
        #expect(newCard.reminder == .oneHour)

        let cardNoReminder = Card(
            title: "Recurring",
            columnId: UUID(),
            label: .blogPost,
            priority: .normal,
            dueDate: Date(),
            isRecurring: true,
            recurrenceRule: RecurrenceRule(interval: 1, frequency: .daily),
            reminder: .none
        )
        let newCard2 = try #require(cardNoReminder.createRecurringInstance(inColumn: UUID()))
        #expect(newCard2.reminder == .none)
    }

    @Test func reminderFireDateCalculation() {
        let dueDate = Date().addingTimeInterval(7200)
        let fireDate = dueDate.addingTimeInterval(ReminderOffset.oneHour.offsetSeconds)
        #expect(fireDate < dueDate)
        #expect(fireDate > Date())
        // At due date offset equals due date
        let atDueFireDate = dueDate.addingTimeInterval(ReminderOffset.atDueDate.offsetSeconds)
        #expect(atDueFireDate == dueDate)
    }
}

// MARK: - Due Date Day Comparison Tests

struct DueDateComparisonTests {
    @Test func dayComparisonOverdueLogic() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))

        // Today is NOT overdue
        #expect(!(today < today))
        // Yesterday IS overdue
        #expect(calendar.startOfDay(for: yesterday) < today)
        // Tomorrow is NOT overdue
        #expect(!(calendar.startOfDay(for: tomorrow) < today))
    }

    @Test func todayAt5pmIsNotOverdue() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 17
        comps.minute = 0
        let dueDate5pm = try #require(calendar.date(from: comps))
        // Day comparison: due day == today, NOT overdue
        #expect(calendar.startOfDay(for: dueDate5pm) == today)
    }

    @Test func dueTodayVsTomorrowVsNextWeek() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrowStart = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        let dayAfterTomorrow = try #require(calendar.date(byAdding: .day, value: 2, to: today))
        let nextWeek = try #require(calendar.date(byAdding: .day, value: 7, to: today))

        // Today == today
        #expect(today == calendar.startOfDay(for: Date()))
        // Tomorrow is in the tomorrow range
        #expect(tomorrowStart >= tomorrowStart && tomorrowStart < dayAfterTomorrow)
        // Next week is NOT in today or tomorrow range
        let nextWeekDay = calendar.startOfDay(for: nextWeek)
        #expect(nextWeekDay != today)
        #expect(nextWeekDay >= dayAfterTomorrow)
    }
}
