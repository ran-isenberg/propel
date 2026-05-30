import Foundation
@testable import Propel
import Testing

// MARK: - Column System Tests

@MainActor
struct ColumnSystemTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel()
        vm.board = Board()
        return vm
    }

    @Test func addColumnInsertsPlainColumnBeforeDone() throws {
        let vm = makeViewModel()
        let before = vm.board.columns.count
        let newId = vm.addColumn()

        #expect(vm.board.columns.count == before + 1)
        let new = try #require(vm.board.columns.first { $0.id == newId })
        #expect(new.isProtected == false)
        // The new column sits before the done column.
        let newPos = vm.board.columns.first { $0.id == newId }?.position ?? -1
        let donePos = vm.column(for: .done)?.position ?? -1
        #expect(newPos < donePos)
        // Positions remain contiguous.
        for (index, column) in vm.sortedColumns.enumerated() {
            #expect(column.position == index)
        }
    }

    @Test func updateColumnPreservesRoleFlags() throws {
        let vm = makeViewModel()
        var done = try #require(vm.column(for: .done))
        done.name = "Shipped"
        done.color = .teal
        done.isDoneStage = false // attempt to strip the role — must be ignored
        vm.updateColumn(done)

        let updated = vm.column(for: .done)
        #expect(updated?.name == "Shipped")
        #expect(updated?.color == .teal)
        #expect(updated?.isDoneStage == true)
    }

    @Test func protectedColumnsCannotBeDeleted() throws {
        let vm = makeViewModel()
        let intakeId = try #require(vm.column(for: .intake)).id
        let blockedId = try #require(vm.column(for: .blocked)).id
        let doneId = try #require(vm.column(for: .done)).id

        #expect(vm.canDeleteColumn(intakeId) == false)
        #expect(vm.canDeleteColumn(blockedId) == false)
        #expect(vm.canDeleteColumn(doneId) == false)

        // A plain column can be deleted.
        let plain = try #require(vm.sortedColumns.first { !$0.isProtected })
        #expect(vm.canDeleteColumn(plain.id) == true)
    }

    @Test func deleteColumnMovesCardsToReplacement() throws {
        let vm = makeViewModel()
        let plain = try #require(vm.sortedColumns.first { !$0.isProtected })
        let intakeId = try #require(vm.column(for: .intake)).id
        vm.createCard(title: "Card", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: plain.id)
        let cardId = vm.board.cards[0].id

        vm.deleteColumn(plain.id, replacementColumnId: intakeId)

        #expect(vm.board.columns.contains { $0.id == plain.id } == false)
        #expect(vm.board.cards.first { $0.id == cardId }?.columnId == intakeId)
    }

    @Test func deleteColumnIntoDoneMarksCardsComplete() throws {
        let vm = makeViewModel()
        let plain = try #require(vm.sortedColumns.first { !$0.isProtected })
        let doneId = try #require(vm.column(for: .done)).id
        vm.createCard(title: "Card", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: plain.id)
        let cardId = vm.board.cards[0].id
        #expect(vm.board.cards[0].completedAt == nil)

        vm.deleteColumn(plain.id, replacementColumnId: doneId)

        let card = vm.board.cards.first { $0.id == cardId }
        #expect(card?.columnId == doneId)
        #expect(card?.completedAt != nil)
    }

    @Test func moveColumnsReindexesPositions() {
        let vm = makeViewModel()
        vm.moveColumns(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        for (index, column) in vm.sortedColumns.enumerated() {
            #expect(column.position == index)
        }
    }

    @Test func toggleBlockedMovesToBlockedColumnAndBack() throws {
        let vm = makeViewModel()
        let intakeId = try #require(vm.column(for: .intake)).id
        let blockedId = try #require(vm.column(for: .blocked)).id
        vm.createCard(title: "Card", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: intakeId)
        let cardId = vm.board.cards[0].id

        vm.toggleCardBlocked(cardId)
        #expect(vm.board.cards.first { $0.id == cardId }?.columnId == blockedId)

        // Unblocking moves the card to a non-protected working column.
        vm.toggleCardBlocked(cardId)
        let destination = vm.board.cards.first { $0.id == cardId }?.columnId
        let destColumn = vm.board.columns.first { $0.id == destination }
        #expect(destColumn?.isBlockedStage == false)
    }

    @Test func movingCardToDoneSetsCompletedAt() throws {
        let vm = makeViewModel()
        let intakeId = try #require(vm.column(for: .intake)).id
        let doneId = try #require(vm.column(for: .done)).id
        vm.createCard(title: "Card", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: intakeId)
        let cardId = vm.board.cards[0].id

        vm.moveCard(cardId, toColumn: doneId)
        #expect(vm.board.cards.first { $0.id == cardId }?.completedAt != nil)

        vm.moveCard(cardId, toColumn: intakeId)
        #expect(vm.board.cards.first { $0.id == cardId }?.completedAt == nil)
    }
}
