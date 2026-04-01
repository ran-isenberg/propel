import Foundation
@testable import Propel
import Testing

// MARK: - Filter Tests

@MainActor
struct FilterTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel()
        vm.board = Board()
        return vm
    }

    @Test func filterByLabel() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Blog", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
        vm.createCard(title: "Video", labelId: LabelDefinition.videoId, priority: .normal, inColumn: colId)
        vm.createCard(title: "Podcast", labelId: LabelDefinition.podcastId, priority: .normal, inColumn: colId)

        vm.filterLabel = LabelDefinition.blogPostId
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 1)
        #expect(cards[0].title == "Blog")
    }

    @Test func filterByPriority() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Urgent", labelId: LabelDefinition.blogPostId, priority: .urgent, inColumn: colId)
        vm.createCard(title: "Normal", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
        vm.createCard(title: "Low", labelId: LabelDefinition.blogPostId, priority: .low, inColumn: colId)

        vm.filterPriority = .urgent
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 1)
        #expect(cards[0].title == "Urgent")
    }

    @Test func filterByBothLabelAndPriority() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "A", labelId: LabelDefinition.blogPostId, priority: .urgent, inColumn: colId)
        vm.createCard(title: "B", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
        vm.createCard(title: "C", labelId: LabelDefinition.videoId, priority: .urgent, inColumn: colId)

        vm.filterLabel = LabelDefinition.blogPostId
        vm.filterPriority = .urgent
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 1)
        #expect(cards[0].title == "A")
    }

    @Test func clearFiltersShowsAll() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "A", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
        vm.createCard(title: "B", labelId: LabelDefinition.videoId, priority: .urgent, inColumn: colId)

        vm.filterLabel = LabelDefinition.blogPostId
        #expect(vm.cardsForColumn(vm.board.columns[0]).count == 1)

        vm.clearFilters()
        #expect(vm.cardsForColumn(vm.board.columns[0]).count == 2)
    }

    @Test func isFilterActiveReflectsState() {
        let vm = makeViewModel()
        #expect(vm.isFilterActive == false)
        vm.filterLabel = LabelDefinition.podcastId
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
        vm.createCard(title: "Blog Backlog", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: backlogId)
        vm.createCard(title: "Video Backlog", labelId: LabelDefinition.videoId, priority: .normal, inColumn: backlogId)
        // Move one to in-progress by directly setting columnId
        vm.board.cards[1].columnId = inProgressId

        vm.filterLabel = LabelDefinition.videoId
        #expect(vm.cardsForColumn(vm.board.columns[0]).isEmpty)
        #expect(vm.cardsForColumn(vm.board.columns[1]).count == 1)
    }
}

// MARK: - Column Sort Config Tests

@MainActor
struct ColumnSortTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel()
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
            Card(title: "Next week", columnId: colId, labelId: LabelDefinition.blogPostId, priority: .low, dueDate: nextWeek),
            Card(title: "Tomorrow", columnId: colId, labelId: LabelDefinition.blogPostId, priority: .urgent, dueDate: tomorrow),
            Card(title: "Today", columnId: colId, labelId: LabelDefinition.blogPostId, priority: .normal, dueDate: now)
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
            Card(title: "Third", columnId: colId, labelId: LabelDefinition.blogPostId, priority: .low, createdAt: t3),
            Card(title: "First", columnId: colId, labelId: LabelDefinition.blogPostId, priority: .urgent, createdAt: t1),
            Card(title: "Second", columnId: colId, labelId: LabelDefinition.blogPostId, priority: .normal, createdAt: t2)
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

// MARK: - Search Tests

@MainActor
struct SearchTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel()
        vm.board = Board()
        return vm
    }

    @Test func searchByTitle() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Write blog post", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
        vm.createCard(title: "Record video", labelId: LabelDefinition.videoId, priority: .normal, inColumn: colId)
        vm.createCard(title: "Podcast episode", labelId: LabelDefinition.podcastId, priority: .normal, inColumn: colId)

        vm.searchText = "blog"
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 1)
        #expect(cards[0].title == "Write blog post")
    }

    @Test func searchByDescription() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Task A", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
        var card = vm.board.cards[0]
        card.description = "Contains the keyword banana"
        vm.updateCard(card)

        vm.createCard(title: "Task B", labelId: LabelDefinition.videoId, priority: .normal, inColumn: colId)

        vm.searchText = "banana"
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 1)
        #expect(cards[0].title == "Task A")
    }

    @Test func searchIsCaseInsensitive() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "UPPERCASE Title", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)

        vm.searchText = "uppercase"
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 1)
    }

    @Test func emptySearchShowsAll() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "A", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
        vm.createCard(title: "B", labelId: LabelDefinition.videoId, priority: .normal, inColumn: colId)

        vm.searchText = ""
        let cards = vm.cardsForColumn(vm.board.columns[0])
        #expect(cards.count == 2)
    }

    @Test func searchResultsProperty() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Alpha", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
        vm.createCard(title: "Beta", labelId: LabelDefinition.videoId, priority: .normal, inColumn: colId)
        vm.createCard(title: "Alpha Two", labelId: LabelDefinition.podcastId, priority: .normal, inColumn: colId)

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

// MARK: - Collapsible Columns Tests

@MainActor
struct CollapsibleColumnsTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel()
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

// MARK: - Auto-Archive Tests

@MainActor
struct AutoArchiveTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel()
        vm.board = Board()
        return vm
    }

    @Test func recentCompletedCardsAreVisible() {
        let vm = makeViewModel()
        let completedId = vm.board.columns[3].id
        vm.board.cards.append(Card(
            title: "Just done",
            columnId: completedId,
            labelId: LabelDefinition.blogPostId,
            completedAt: Date()
        ))
        vm.autoArchiveDays = 7
        let cards = vm.cardsForColumn(vm.board.columns[3])
        #expect(cards.count == 1)
    }

    @Test func oldCompletedCardsAreHidden() throws {
        let vm = makeViewModel()
        let completedId = vm.board.columns[3].id
        let tenDaysAgo = try #require(Calendar.current.date(byAdding: .day, value: -10, to: Date()))
        vm.board.cards.append(Card(
            title: "Old done",
            columnId: completedId,
            labelId: LabelDefinition.blogPostId,
            completedAt: tenDaysAgo
        ))
        vm.autoArchiveDays = 7
        let cards = vm.cardsForColumn(vm.board.columns[3])
        #expect(cards.isEmpty)
    }

    @Test func disabledAutoArchiveShowsAll() throws {
        let vm = makeViewModel()
        let completedId = vm.board.columns[3].id
        let oldDate = try #require(Calendar.current.date(byAdding: .day, value: -30, to: Date()))
        vm.board.cards.append(Card(
            title: "Very old",
            columnId: completedId,
            labelId: LabelDefinition.blogPostId,
            completedAt: oldDate
        ))
        vm.autoArchiveDays = 0
        let cards = vm.cardsForColumn(vm.board.columns[3])
        #expect(cards.count == 1)
    }
}
