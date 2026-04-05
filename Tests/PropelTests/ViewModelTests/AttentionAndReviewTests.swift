import Foundation
@testable import Propel
import Testing

// MARK: - Attention View Tests

@MainActor
struct AttentionViewTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel()
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
            labelId: LabelDefinition.blogPostId,
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
            labelId: LabelDefinition.blogPostId,
            dueDate: tomorrow
        ))
        #expect(vm.attentionCards.count == 1)
    }

    @Test func blockedCardsAppearInAttention() {
        let vm = makeViewModel()
        let blockedId = vm.board.columns[2].id
        vm.board.cards.append(Card(
            title: "Blocked card",
            columnId: blockedId,
            labelId: LabelDefinition.blogPostId
        ))
        #expect(vm.attentionCards.count == 1)
    }

    @Test func completedCardsExcludedFromAttention() throws {
        let vm = makeViewModel()
        let completedId = vm.board.columns[4].id
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        vm.board.cards.append(Card(
            title: "Done overdue",
            columnId: completedId,
            labelId: LabelDefinition.blogPostId,
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
            labelId: LabelDefinition.blogPostId,
            dueDate: nextMonth
        ))
        #expect(vm.attentionCards.isEmpty)
    }

    @Test func overdueCount() throws {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        vm.board.cards.append(Card(title: "OD1", columnId: colId, labelId: LabelDefinition.blogPostId, dueDate: yesterday))
        vm.board.cards.append(Card(title: "OD2", columnId: colId, labelId: LabelDefinition.videoId, dueDate: yesterday))
        #expect(vm.overdueCount == 2)
    }

    @Test func blockedCountProperty() {
        let vm = makeViewModel()
        let blockedId = vm.board.columns[2].id
        vm.board.cards.append(Card(title: "B1", columnId: blockedId, labelId: LabelDefinition.blogPostId))
        vm.board.cards.append(Card(title: "B2", columnId: blockedId, labelId: LabelDefinition.videoId))
        #expect(vm.blockedCount == 2)
    }
}

// MARK: - Weekly Review Tests

@MainActor
struct WeeklyReviewTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel()
        vm.board = Board()
        return vm
    }

    @Test func reviewDataCountsCompletedThisWeek() {
        let vm = makeViewModel()
        let completedId = vm.board.columns[4].id
        vm.board.cards.append(Card(
            title: "Done today",
            columnId: completedId,
            labelId: LabelDefinition.blogPostId,
            completedAt: Date()
        ))
        vm.board.cards.append(Card(
            title: "Done long ago",
            columnId: completedId,
            labelId: LabelDefinition.videoId,
            completedAt: Calendar.current.date(byAdding: .day, value: -30, to: Date())
        ))
        let data = vm.weeklyReviewData
        #expect(data.completedCards.count == 1)
        #expect(data.completedCards[0].title == "Done today")
    }

    @Test func reviewDataCountsCreatedThisWeek() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "New card", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
        let data = vm.weeklyReviewData
        #expect(data.createdCards.count == 1)
    }

    @Test func reviewDataCountsInProgress() {
        let vm = makeViewModel()
        let inProgressId = vm.board.columns[1].id
        vm.board.cards.append(Card(title: "WIP", columnId: inProgressId, labelId: LabelDefinition.blogPostId))
        let data = vm.weeklyReviewData
        #expect(data.inProgressCards.count == 1)
    }

    @Test func reviewDataCountsOverdue() throws {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        vm.board.cards.append(Card(title: "Late", columnId: colId, labelId: LabelDefinition.blogPostId, dueDate: yesterday))
        let data = vm.weeklyReviewData
        #expect(data.overdueCards.count == 1)
    }

    @Test func reviewDataTotalCards() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "A", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
        vm.createCard(title: "B", labelId: LabelDefinition.videoId, priority: .normal, inColumn: colId)
        let data = vm.weeklyReviewData
        #expect(data.totalCards == 2)
    }
}

// MARK: - Menu Bar Badge Tests

@MainActor
struct MenuBarBadgeTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel()
        vm.board = Board()
        return vm
    }

    @Test func badgeCountShowsOverdue() throws {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        vm.board.cards.append(Card(title: "OD", columnId: colId, labelId: LabelDefinition.blogPostId, dueDate: yesterday))
        #expect(vm.menuBarBadgeCount == 1)
    }

    @Test func zeroBadgeWhenAllClear() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "Normal", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
        #expect(vm.menuBarBadgeCount == 0)
    }
}

// MARK: - Emoji Support Tests

@MainActor
struct EmojiSupportTests {
    private func makeViewModel() -> BoardViewModel {
        let vm = BoardViewModel()
        vm.board = Board()
        return vm
    }

    @Test func cardTitleSupportsEmoji() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "🚀 Launch Day", labelId: LabelDefinition.blogPostId, priority: .urgent, inColumn: colId)
        let card = vm.board.cards.first
        #expect(card?.title == "🚀 Launch Day")
    }

    @Test func cardDescriptionSupportsEmoji() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(
            title: "Test",
            labelId: LabelDefinition.blogPostId,
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
        vm.createCard(title: "🎯🔥💡", labelId: LabelDefinition.videoId, priority: .normal, inColumn: colId)
        let card = vm.board.cards.first
        #expect(card?.title == "🎯🔥💡")
        #expect(card?.title.count == 3)
    }

    @Test func searchFindsEmojiInTitle() {
        let vm = makeViewModel()
        let colId = vm.board.columns[0].id
        vm.createCard(title: "🚀 Launch", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
        vm.createCard(title: "Review PR", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
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
            labelId: LabelDefinition.blogPostId,
            priority: .normal,
            description: "Important 🔥 task",
            inColumn: colId
        )
        vm.createCard(title: "Other", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: colId)
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
            labelId: LabelDefinition.conferenceTalkId,
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
            labelId: LabelDefinition.blogPostId
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
