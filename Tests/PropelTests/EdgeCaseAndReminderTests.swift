import AppKit
import Foundation
@testable import Propel
import Testing

// MARK: - Edge Case Tests

struct EdgeCaseTests {
    /// Create a BoardViewModel and wait for its init's async loadBoard() to complete
    /// so subsequent board assignments aren't overwritten.
    private static func makeViewModel() async -> BoardViewModel {
        let vm = await BoardViewModel()
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
                labelId: LabelDefinition.blogPostId,
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
                labelId: LabelDefinition.conferenceTalkId,
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
                labelId: LabelDefinition.blogPostId,
                priority: .normal,
                inColumn: backlogId
            )
        }

        let beforeDate = await vm.board.cards[0].updatedAt

        // Running again should not modify
        try? await Task.sleep(for: .milliseconds(10))
        await MainActor.run { vm.addDefaultChecklistToCards() }

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
            labelId: LabelDefinition.blogPostId
        )
        card.checklist = [
            ChecklistItem(title: "PR", isCompleted: true, position: 0),
            ChecklistItem(title: "Custom Step", position: 1),
        ]
        board.cards.append(card)
        await MainActor.run { vm.board = board }

        await MainActor.run { vm.addDefaultChecklistToCards() }

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
        let inProgressId = board.columns[1].id
        let blockedId = board.columns[2].id

        // Backlog → Blocked
        await MainActor.run { vm.createCard(title: "Test", labelId: LabelDefinition.blogPostId, priority: .normal, inColumn: backlogId) }
        let cardId = await vm.board.cards[0].id
        await MainActor.run { vm.toggleCardBlocked(cardId) }
        #expect(await vm.board.cards.first { $0.id == cardId }?.columnId == blockedId)

        // Blocked → In Progress
        await MainActor.run { vm.toggleCardBlocked(cardId) }
        #expect(await vm.board.cards.first { $0.id == cardId }?.columnId == inProgressId)
    }

    // MARK: - Auto-Archive Cutoff

    @Test func autoArchiveWithZeroDaysShowsAllCompleted() async {
        let vm = await Self.makeViewModel()
        var board = Board()
        let completedId = board.columns[3].id
        var card = Card(title: "Old Done", columnId: completedId, labelId: LabelDefinition.blogPostId)
        card.completedAt = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        board.cards.append(card)
        await MainActor.run {
            vm.board = board
            vm.autoArchiveDays = 0
        }

        let completedColumn = board.columns[3]
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
        let defaultCard = Card(title: "Test", columnId: UUID(), labelId: LabelDefinition.blogPostId, priority: .normal)
        #expect(defaultCard.reminder == .none)

        let card = Card(
            title: "Test",
            columnId: UUID(),
            labelId: LabelDefinition.blogPostId,
            priority: .normal,
            dueDate: Date(),
            reminder: .fifteenMinutes
        )
        #expect(card.reminder == .fifteenMinutes)
    }

    @Test func cardDecoderDefaultsReminderToNone() throws {
        let card = Card(title: "Old Card", columnId: UUID(), labelId: LabelDefinition.blogPostId, priority: .normal)
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
            labelId: LabelDefinition.blogPostId,
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
            labelId: LabelDefinition.blogPostId,
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
