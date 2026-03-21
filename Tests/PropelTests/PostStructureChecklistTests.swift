@testable import Propel
import Testing

// MARK: - Post Structure Checklist Tests

@MainActor
struct PostStructureChecklistTests {
    private static func makeViewModel() async -> BoardViewModel {
        let vm = BoardViewModel()
        vm.board = Board()
        return vm
    }

    @Test func blogPostChecklistIncludesPostStructureFirst() async {
        let vm = await Self.makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Blog", label: .blogPost, priority: .normal, inColumn: colId)
        let titles = vm.board.cards[0].checklist.map(\.title)
        #expect(titles[0] == "Post Structure")
        #expect(titles[1] == "Medium")
        #expect(titles[2] == "LinkedIn Newsletter")
        #expect(titles[3] == "PR")
    }

    @Test func postStructureRetroactiveAndNoDuplicates() async {
        let vm = await Self.makeViewModel()
        var board = Board()
        // Card without Post Structure (simulates old data)
        var oldCard = Card(title: "Old Blog", columnId: board.columns[0].id, label: .blogPost)
        oldCard.checklist = [
            ChecklistItem(title: "PR", isCompleted: true, position: 0),
            ChecklistItem(title: "Merge", position: 1),
        ]
        // Card that already has Post Structure
        var existingCard = Card(title: "Blog2", columnId: board.columns[0].id, label: .blogPost)
        existingCard.checklist = [
            ChecklistItem(title: "Post Structure", isCompleted: true, position: 0),
            ChecklistItem(title: "PR", position: 1),
        ]
        board.cards.append(contentsOf: [oldCard, existingCard])
        await MainActor.run { vm.board = board }
        await MainActor.run { vm.addDefaultChecklistToBlogCards() }

        // Old card: Post Structure inserted BEFORE PR, completion preserved
        let updated0 = vm.board.cards[0]
        let titles0 = updated0.checklist.map(\.title)
        #expect(titles0[0] == "Post Structure")
        #expect(titles0[1] == "Medium")
        #expect(titles0[2] == "LinkedIn Newsletter")
        #expect(titles0[3] == "PR")
        #expect(updated0.checklist.filter { $0.title == "PR" }.count == 1)
        #expect(updated0.checklist.first { $0.title == "PR" }?.isCompleted == true)

        // Existing card: Post Structure not duplicated, completion preserved
        let updated1 = vm.board.cards[1]
        #expect(updated1.checklist.filter { $0.title == "Post Structure" }.count == 1)
        #expect(updated1.checklist.first { $0.title == "Post Structure" }?.isCompleted == true)
    }

    @Test func postStructureReorderedWhenAllItemsPresentButWrongOrder() async {
        let vm = await Self.makeViewModel()
        var board = Board()
        // Card with all default items but Post Structure at the end (wrong order)
        var card = Card(title: "Rust Blog", columnId: board.columns[0].id, label: .blogPost)
        card.checklist = [
            ChecklistItem(title: "PR", position: 0),
            ChecklistItem(title: "Merge", isCompleted: true, position: 1),
            ChecklistItem(title: "GA", position: 2),
            ChecklistItem(title: "LinkedIn", position: 3),
            ChecklistItem(title: "X", position: 4),
            ChecklistItem(title: "Heroes", position: 5),
            ChecklistItem(title: "Post Structure", position: 6),
            ChecklistItem(title: "Medium", position: 7),
            ChecklistItem(title: "LinkedIn Newsletter", position: 8),
        ]
        board.cards.append(card)
        await MainActor.run { vm.board = board }
        await MainActor.run { vm.addDefaultChecklistToBlogCards() }

        let updated = vm.board.cards[0]
        let titles = updated.checklist.map(\.title)
        #expect(titles[0] == "Post Structure")
        #expect(titles[1] == "Medium")
        #expect(titles[2] == "LinkedIn Newsletter")
        #expect(titles[3] == "PR")
        #expect(titles[4] == "Merge")
        // Completion state preserved after reorder
        #expect(updated.checklist.first { $0.title == "Merge" }?.isCompleted == true)
        // No duplicates
        #expect(updated.checklist.filter { $0.title == "Post Structure" }.count == 1)
    }
}
