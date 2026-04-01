import Foundation
@testable import Propel
import Testing

// MARK: - BoardViewModel Tests

@MainActor
struct BoardViewModelTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel()
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

    // MARK: - Clear Completed Cards

    @Test func clearCompletedCardsRemovesOnlyCompletedCards() {
        let vm = makeViewModel()
        let backlogId = vm.board.columns[0].id
        let completedId = vm.board.columns[3].id
        vm.createCard(title: "Active", label: .blogPost, priority: .normal, inColumn: backlogId)
        vm.createCard(title: "Done 1", label: .video, priority: .low, inColumn: backlogId)
        vm.createCard(title: "Done 2", label: .podcast, priority: .normal, inColumn: backlogId)
        vm.moveCard(vm.board.cards[1].id, toColumn: completedId)
        vm.moveCard(vm.board.cards[2].id, toColumn: completedId)
        vm.clearCompletedCards()
        #expect(vm.board.cards.count == 1)
        #expect(vm.board.cards[0].title == "Active")
    }

    @Test func clearCompletedCardsClearsSelectedCardIfCompleted() {
        let vm = makeViewModel()
        let backlogId = vm.board.columns[0].id
        let completedId = vm.board.columns[3].id
        vm.createCard(title: "Done", label: .blogPost, priority: .normal, inColumn: backlogId)
        let cardId = vm.board.cards[0].id
        vm.moveCard(cardId, toColumn: completedId)
        vm.selectedCardId = cardId
        vm.clearCompletedCards()
        #expect(vm.board.cards.isEmpty)
        #expect(vm.selectedCardId == nil)
    }

    @Test func clearCompletedCardsKeepsSelectedCardIfNotCompleted() {
        let vm = makeViewModel()
        let backlogId = vm.board.columns[0].id
        let completedId = vm.board.columns[3].id
        vm.createCard(title: "Active", label: .blogPost, priority: .normal, inColumn: backlogId)
        vm.createCard(title: "Done", label: .video, priority: .low, inColumn: backlogId)
        let activeId = vm.board.cards[0].id
        vm.selectedCardId = activeId
        vm.moveCard(vm.board.cards[1].id, toColumn: completedId)
        vm.clearCompletedCards()
        #expect(vm.board.cards.count == 1)
        #expect(vm.selectedCardId == activeId)
    }

    @Test func clearCompletedCardsWhenNoneCompletedIsNoOp() {
        let vm = makeViewModel()
        let backlogId = vm.board.columns[0].id
        vm.createCard(title: "Active", label: .blogPost, priority: .normal, inColumn: backlogId)
        vm.clearCompletedCards()
        #expect(vm.board.cards.count == 1)
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
        let completedId = vm.board.columns[3].id
        vm.createCard(title: "Done", label: .podcast, priority: .normal, inColumn: backlogId)
        let cardId = vm.board.cards[0].id
        vm.moveCard(cardId, toColumn: completedId)
        #expect(vm.board.cards[0].completedAt != nil)
    }

    @Test func moveCardOutOfCompletedClearsCompletedAt() {
        let vm = makeViewModel()
        let backlogId = vm.board.columns[0].id
        let completedId = vm.board.columns[3].id
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
        let completedId = vm.board.columns[3].id
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
        let completedId = vm.board.columns[3].id
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

    @Test func toggleCardBlockedMovesToBlocked() {
        let vm = makeViewModel()
        let inProgressId = vm.board.columns[1].id
        let blockedId = vm.board.columns[2].id
        vm.createCard(title: "Block me", label: .video, priority: .normal, inColumn: inProgressId)
        let cardId = vm.board.cards[0].id
        vm.toggleCardBlocked(cardId)
        #expect(vm.board.cards[0].columnId == blockedId)
    }

    @Test func toggleCardBlockedUnblocksToInProgress() {
        let vm = makeViewModel()
        let blockedId = vm.board.columns[2].id
        let inProgressId = vm.board.columns[1].id
        vm.createCard(title: "Unblock me", label: .video, priority: .normal, inColumn: blockedId)
        let cardId = vm.board.cards[0].id
        vm.toggleCardBlocked(cardId)
        #expect(vm.board.cards[0].columnId == inProgressId)
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
        #expect(columns.count == 4)
        for i in 0 ..< columns.count {
            #expect(columns[i].position == i)
        }
    }

    @Test func columnForStatusFindsCorrectColumn() {
        let vm = makeViewModel()
        #expect(vm.column(for: .backlog)?.status == .backlog)
        #expect(vm.column(for: .inProgress)?.status == .inProgress)
        #expect(vm.column(for: .blocked)?.status == .blocked)
        #expect(vm.column(for: .completed)?.status == .completed)
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

    // MARK: - Checklist Add & Reorder

    @Test func addChecklistItemToNonBlogPostCard() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "My Video", label: .video, priority: .normal, inColumn: colId)
        var card = vm.board.cards[0]
        #expect(card.checklist.isEmpty)
        card.checklist.append(ChecklistItem(title: "Record", position: 0))
        card.checklist.append(ChecklistItem(title: "Edit", position: 1))
        vm.updateCard(card)
        #expect(vm.board.cards[0].checklist.count == 2)
        #expect(vm.board.cards[0].checklist[0].title == "Record")
        #expect(vm.board.cards[0].checklist[1].title == "Edit")
    }

    @Test func addChecklistItemToAllCategories() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        let nonBlogLabels: [Label] = [.conferenceTalk, .video, .podcast, .code, .article]
        for label in nonBlogLabels {
            vm.createCard(title: "\(label.rawValue) task", label: label, priority: .normal, inColumn: colId)
        }
        for index in vm.board.cards.indices {
            var card = vm.board.cards[index]
            card.checklist.append(ChecklistItem(title: "Step 1", position: 0))
            vm.updateCard(card)
        }
        for card in vm.board.cards {
            #expect(card.checklist.count == 1)
            #expect(card.checklist[0].title == "Step 1")
        }
    }

    @Test func reorderChecklistItems() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Task", label: .video, priority: .normal, inColumn: colId)
        var card = vm.board.cards[0]
        card.checklist = [
            ChecklistItem(title: "A", position: 0),
            ChecklistItem(title: "B", position: 1),
            ChecklistItem(title: "C", position: 2),
        ]
        vm.updateCard(card)
        // Simulate reorder: move C (index 2) to index 0
        card = vm.board.cards[0]
        let moved = card.checklist.remove(at: 2)
        card.checklist.insert(moved, at: 0)
        for i in card.checklist.indices { card.checklist[i].position = i }
        vm.updateCard(card)
        #expect(vm.board.cards[0].checklist.map(\.title) == ["C", "A", "B"])
        #expect(vm.board.cards[0].checklist.map(\.position) == [0, 1, 2])
    }

    @Test func reorderChecklistPreservesCompletionState() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Task", label: .podcast, priority: .normal, inColumn: colId)
        var card = vm.board.cards[0]
        card.checklist = [
            ChecklistItem(title: "Done", isCompleted: true, position: 0),
            ChecklistItem(title: "Pending", isCompleted: false, position: 1),
        ]
        vm.updateCard(card)
        // Swap order
        card = vm.board.cards[0]
        let moved = card.checklist.remove(at: 1)
        card.checklist.insert(moved, at: 0)
        for i in card.checklist.indices { card.checklist[i].position = i }
        vm.updateCard(card)
        #expect(vm.board.cards[0].checklist[0].title == "Pending")
        #expect(vm.board.cards[0].checklist[0].isCompleted == false)
        #expect(vm.board.cards[0].checklist[1].title == "Done")
        #expect(vm.board.cards[0].checklist[1].isCompleted == true)
    }
}
