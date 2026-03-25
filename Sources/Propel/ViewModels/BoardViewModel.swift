import SwiftUI
import UserNotifications

private let blogPostDefaultChecklist: [ChecklistItem] = [
    ChecklistItem(title: "Post Structure", position: 0),
    ChecklistItem(title: "Medium", position: 1),
    ChecklistItem(title: "LinkedIn Newsletter", position: 2),
    ChecklistItem(title: "PR", position: 3),
    ChecklistItem(title: "Merge", position: 4),
    ChecklistItem(title: "GA", position: 5),
    ChecklistItem(title: "LinkedIn", position: 6),
    ChecklistItem(title: "X", position: 7),
    ChecklistItem(title: "Heroes", position: 8),
]

@Observable
@MainActor
final class BoardViewModel {
    var board: Board = .init()
    var selectedCardId: UUID?
    var isCreatingCard: Bool = false
    var creationTargetStageId: UUID?
    var errorMessage: String?

    var creationTargetColumnId: UUID? {
        get { creationTargetStageId }
        set { creationTargetStageId = newValue }
    }

    var filterLabel: Label?
    var filterPriority: Priority?
    var searchText: String = ""
    var isSearching: Bool = false
    var collapsedStageIds: Set<UUID> = []

    var collapsedColumnIds: Set<UUID> {
        get { collapsedStageIds }
        set { collapsedStageIds = newValue }
    }

    var autoArchiveDays: Int = 7
    var showDoneFirst: Bool = false
    var showAttentionView: Bool = false
    var deliveredReminderCount: Int = 0

    private var debouncedSave: DebouncedSave?
    private var notificationCheckTask: Task<Void, Never>?

    init() {
        debouncedSave = DebouncedSave { [weak self] in
            await self?.persistBoard()
        }
        Task {
            await loadBoard()
            requestNotificationPermission()
            scheduleNotificationCheck()
            await refreshDeliveredNotificationCount()
        }
    }
}

extension BoardViewModel {
    var isFilterActive: Bool {
        filterLabel != nil || filterPriority != nil
    }

    var sortedStages: [Stage] {
        board.sortedStages
    }

    var sortedColumns: [Stage] {
        sortedStages
    }

    var visibleStages: [Stage] {
        if showDoneFirst {
            return sortedStages.sorted { lhs, rhs in
                if lhs.isDoneStage != rhs.isDoneStage {
                    return lhs.isDoneStage && !rhs.isDoneStage
                }
                return lhs.position < rhs.position
            }
        }
        return sortedStages
    }

    var defaultIntakeStage: Stage? {
        board.defaultIntakeStage
    }

    var doneStages: [Stage] {
        board.doneStages
    }

    var searchResults: [Card] {
        guard !searchText.isEmpty else { return [] }
        return board.cards.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var attentionCards: [Card] {
        let now = Date()
        let soonThreshold = Calendar.current.date(byAdding: .day, value: 3, to: now) ?? now

        return board.cards.filter { card in
            guard !isDoneStage(card.stageId) else { return false }
            if card.isBlocked { return true }
            if let due = card.dueDate, due < now { return true }
            if let due = card.dueDate, due <= soonThreshold { return true }
            return false
        }.sorted { a, b in
            let aOverdue = a.dueDate.map { $0 < now } ?? false
            let bOverdue = b.dueDate.map { $0 < now } ?? false
            if aOverdue != bOverdue { return aOverdue }
            if a.isBlocked != b.isBlocked { return a.isBlocked }
            return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
        }
    }

    var overdueCount: Int {
        let now = Date()
        return board.cards.count(where: { card in
            guard !isDoneStage(card.stageId), let due = card.dueDate else { return false }
            return due < now
        })
    }

    var blockedCount: Int {
        board.cards.count(where: { $0.isBlocked && !isDoneStage($0.stageId) })
    }

    var activeCount: Int {
        board.cards.count(where: { !$0.isBlocked && !isDoneStage($0.stageId) })
    }

    var doneCount: Int {
        board.cards.count(where: { isDoneStage($0.stageId) })
    }

    var weeklyReviewData: WeeklyReviewData {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        let completedThisWeek = board.cards.filter { card in
            guard let completedAt = card.completedAt else { return false }
            return completedAt >= weekAgo
        }

        let createdThisWeek = board.cards.filter { $0.createdAt >= weekAgo }
        let activeCards = board.cards.filter { !isDoneStage($0.stageId) && !$0.isBlocked }
        let blockedCards = board.cards.filter { !isDoneStage($0.stageId) && $0.isBlocked }
        let overdueCards = board.cards.filter { card in
            guard !isDoneStage(card.stageId), let due = card.dueDate else { return false }
            return due < now
        }

        return WeeklyReviewData(
            completedCards: completedThisWeek,
            createdCards: createdThisWeek,
            activeCards: activeCards,
            blockedCards: blockedCards,
            overdueCards: overdueCards,
            totalCards: board.cards.count
        )
    }

    var menuBarBadgeCount: Int {
        overdueCount + deliveredReminderCount
    }

    var selectedCard: Card? {
        guard let id = selectedCardId else { return nil }
        return board.cards.first { $0.id == id }
    }

    var showSidePanel: Bool {
        selectedCardId != nil || isCreatingCard
    }
}

extension BoardViewModel {
    func loadBoard() async {
        do {
            board = try await StorageService.shared.loadBoard()
            addDefaultChecklistToBlogCards()
        } catch {
            errorMessage = "Failed to load board: \(error.localizedDescription)"
            board = Board()
        }
    }

    func scheduleBoardSave() {
        scheduleSave()
    }

    func clearFilters() {
        filterLabel = nil
        filterPriority = nil
    }

    func toggleSearch() {
        isSearching.toggle()
        if !isSearching {
            searchText = ""
        }
    }

    func stage(withId stageId: UUID) -> Stage? {
        board.stage(withId: stageId)
    }

    func cardsForStage(_ stage: Stage) -> [Card] {
        var cards = board.cardsForStage(stage)
        if let label = filterLabel {
            cards = cards.filter { $0.label == label }
        }
        if let priority = filterPriority {
            cards = cards.filter { $0.priority == priority }
        }
        if !searchText.isEmpty {
            cards = cards.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                    $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        if autoArchiveDays > 0, stage.isDoneStage {
            let cutoff = Calendar.current.date(byAdding: .day, value: -autoArchiveDays, to: Date()) ?? Date()
            cards = cards.filter { card in
                guard let completedAt = card.completedAt else { return true }
                return completedAt > cutoff
            }
        }
        return cards
    }

    func cardsForColumn(_ stage: Stage) -> [Card] {
        cardsForStage(stage)
    }

    func isDoneStage(_ stageId: UUID) -> Bool {
        stage(withId: stageId)?.isDoneStage == true
    }

    func canBlock(_ card: Card) -> Bool {
        !isDoneStage(card.stageId)
    }

    func toggleStageCollapsed(_ stageId: UUID) {
        if collapsedStageIds.contains(stageId) {
            collapsedStageIds.remove(stageId)
        } else {
            collapsedStageIds.insert(stageId)
        }
    }

    func toggleColumnCollapsed(_ columnId: UUID) {
        toggleStageCollapsed(columnId)
    }

    func isStageCollapsed(_ stageId: UUID) -> Bool {
        collapsedStageIds.contains(stageId)
    }

    func isColumnCollapsed(_ columnId: UUID) -> Bool {
        isStageCollapsed(columnId)
    }

    func updateStageSort(_ stageId: UUID, sortBy: [SortField]) {
        guard let index = board.stages.firstIndex(where: { $0.id == stageId }) else { return }
        board.stages[index].sortBy = sortBy
        scheduleSave()
    }

    func updateColumnSort(_ columnId: UUID, sortBy: [SortField]) {
        updateStageSort(columnId, sortBy: sortBy)
    }
}

extension BoardViewModel {
    private static var isRunningInApp: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private func requestNotificationPermission() {
        guard Self.isRunningInApp else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func scheduleNotificationCheck() {
        guard Self.isRunningInApp else { return }
        notificationCheckTask?.cancel()
        notificationCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(600))
                guard !Task.isCancelled else { return }
                await self?.checkDueDateNotifications()
            }
        }
    }

    func refreshDeliveredNotificationCount() async {
        guard Self.isRunningInApp else { return }
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        let reminderCount = delivered.filter { $0.request.identifier.hasPrefix("reminder-") }.count
        deliveredReminderCount = reminderCount
    }

    func scheduleReminder(for card: Card) {
        guard Self.isRunningInApp else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["reminder-\(card.id)"])

        guard !isDoneStage(card.stageId),
              card.reminder != .none,
              let dueDate = card.dueDate
        else { return }

        let fireDate = dueDate.addingTimeInterval(card.reminder.offsetSeconds)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = dueDate == Calendar.current.startOfDay(for: dueDate) ? .none : .short
        let dueString = formatter.string(from: dueDate)
        content.body = "\"\(card.title)\" — due \(card.reminder == .atDueDate ? "now" : dueString)"
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reminder-\(card.id)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    private func persistBoard() async {
        do {
            try await StorageService.shared.saveBoard(board)
        } catch {
            errorMessage = "Failed to save board: \(error.localizedDescription)"
        }
    }

    private func scheduleSave() {
        board.stages = Board.normalizedStages(board.stages)
        board.cards = Board.normalizedCards(board.cards, for: board.stages)
        board.updatedAt = Date()
        debouncedSave?.schedule()
    }

    private func checkDueDateNotifications() async {
        guard Self.isRunningInApp else { return }
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today) ?? today

        for card in board.cards {
            guard let dueDate = card.dueDate, !isDoneStage(card.stageId) else { continue }
            if card.reminder != .none { continue }

            let dueDay = calendar.startOfDay(for: dueDate)

            if dueDay < today {
                await sendNotification(
                    title: "Overdue",
                    body: "\"\(card.title)\" is past due",
                    id: "overdue-\(card.id)"
                )
            } else if dueDay == today {
                await sendNotification(
                    title: "Due Today",
                    body: "\"\(card.title)\" is due today",
                    id: "due-soon-\(card.id)"
                )
            } else if dueDay >= tomorrowStart, dueDay < dayAfterTomorrow {
                await sendNotification(
                    title: "Due Tomorrow",
                    body: "\"\(card.title)\" is due tomorrow",
                    id: "due-soon-\(card.id)"
                )
            }
        }
    }

    private func sendNotification(title: String, body: String, id: String) async {
        guard Self.isRunningInApp else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func cancelReminder(for cardId: UUID) {
        guard Self.isRunningInApp else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["reminder-\(cardId)"])
    }
}

extension BoardViewModel {
    func createCard(
        title: String,
        label: Label,
        priority: Priority,
        description: String = "",
        dueDate: Date? = nil,
        isRecurring: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        reminder: ReminderOffset = .none,
        inStage stageId: UUID
    ) {
        let checklist = label == .blogPost ? blogPostDefaultChecklist : []
        var card = Card(
            title: title,
            description: description,
            stageId: stageId,
            label: label,
            priority: priority,
            dueDate: dueDate,
            checklist: checklist,
            isRecurring: isRecurring,
            recurrenceRule: recurrenceRule,
            reminder: reminder
        )
        normalizeCardState(&card)
        board.cards.append(card)
        isCreatingCard = false
        creationTargetStageId = nil
        selectedCardId = card.id
        scheduleReminder(for: card)
        scheduleSave()
    }

    func createCard(
        title: String,
        label: Label,
        priority: Priority,
        description: String = "",
        dueDate: Date? = nil,
        isRecurring: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        reminder: ReminderOffset = .none,
        inColumn columnId: UUID
    ) {
        createCard(
            title: title,
            label: label,
            priority: priority,
            description: description,
            dueDate: dueDate,
            isRecurring: isRecurring,
            recurrenceRule: recurrenceRule,
            reminder: reminder,
            inStage: columnId
        )
    }

    func addDefaultChecklistToBlogCards() {
        var didModify = false
        for index in board.cards.indices where board.cards[index].label == .blogPost {
            let existing = Set(board.cards[index].checklist.map(\.title))
            let missing = blogPostDefaultChecklist.filter { !existing.contains($0.title) }

            let currentTitles = board.cards[index].checklist.map(\.title)
            let defaultTitles = Set(blogPostDefaultChecklist.map(\.title))
            let currentDefaultOrder = currentTitles.filter { defaultTitles.contains($0) }
            let expectedOrder = blogPostDefaultChecklist.map(\.title).filter { existing.contains($0) }
            let needsReorder = currentDefaultOrder != expectedOrder

            if !missing.isEmpty || needsReorder {
                let customItems = board.cards[index].checklist.filter { !defaultTitles.contains($0.title) }
                var merged: [ChecklistItem] = []
                for defaultItem in blogPostDefaultChecklist {
                    if let existingItem = board.cards[index].checklist.first(where: { $0.title == defaultItem.title }) {
                        merged.append(ChecklistItem(
                            id: existingItem.id,
                            title: existingItem.title,
                            isCompleted: existingItem.isCompleted,
                            position: merged.count
                        ))
                    } else {
                        merged.append(ChecklistItem(title: defaultItem.title, position: merged.count))
                    }
                }
                for item in customItems {
                    merged.append(ChecklistItem(
                        id: item.id,
                        title: item.title,
                        isCompleted: item.isCompleted,
                        position: merged.count
                    ))
                }
                board.cards[index].checklist = merged
                board.cards[index].updatedAt = Date()
                didModify = true
            }
        }
        if didModify {
            scheduleSave()
        }
    }

    func updateCard(_ card: Card) {
        guard let index = board.cards.firstIndex(where: { $0.id == card.id }) else { return }
        var updated = card
        updated.updatedAt = Date()
        normalizeCardState(&updated)
        board.cards[index] = updated
        scheduleReminder(for: updated)
        scheduleSave()
    }

    func deleteCard(_ cardId: UUID) {
        cancelReminder(for: cardId)
        board.cards.removeAll { $0.id == cardId }
        if selectedCardId == cardId {
            selectedCardId = nil
        }
        scheduleSave()
    }

    func duplicateCard(_ cardId: UUID) {
        guard let original = board.cards.first(where: { $0.id == cardId }) else { return }
        var copy = original
        copy.id = UUID()
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.completedAt = nil
        copy.isBlocked = false
        copy.checklist = original.checklist.map {
            ChecklistItem(id: UUID(), title: $0.title, isCompleted: false, position: $0.position)
        }
        normalizeCardState(&copy)
        board.cards.append(copy)
        scheduleSave()
    }

    func changeCardPriority(_ cardId: UUID, to priority: Priority) {
        guard let index = board.cards.firstIndex(where: { $0.id == cardId }) else { return }
        board.cards[index].priority = priority
        board.cards[index].updatedAt = Date()
        scheduleSave()
    }

    func changeCardLabel(_ cardId: UUID, to label: Label) {
        guard let index = board.cards.firstIndex(where: { $0.id == cardId }) else { return }
        board.cards[index].label = label
        board.cards[index].updatedAt = Date()
        scheduleSave()
    }

    func changeCardDueDate(_ cardId: UUID, to dueDate: Date?) {
        guard let index = board.cards.firstIndex(where: { $0.id == cardId }) else { return }
        board.cards[index].dueDate = dueDate
        board.cards[index].updatedAt = Date()
        scheduleReminder(for: board.cards[index])
        scheduleSave()
    }

    func toggleCardBlocked(_ cardId: UUID) {
        guard let index = board.cards.firstIndex(where: { $0.id == cardId }) else { return }
        guard !isDoneStage(board.cards[index].stageId) else { return }
        board.cards[index].isBlocked.toggle()
        board.cards[index].updatedAt = Date()
        scheduleSave()
    }

    func moveCard(_ cardId: UUID, toStage targetStageId: UUID) {
        guard let index = board.cards.firstIndex(where: { $0.id == cardId }) else { return }
        let previousStageId = board.cards[index].stageId
        guard previousStageId != targetStageId else { return }

        let targetWasDone = isDoneStage(targetStageId)
        let previousWasDone = isDoneStage(previousStageId)

        board.cards[index].stageId = targetStageId
        board.cards[index].updatedAt = Date()

        if targetWasDone {
            board.cards[index].completedAt = Date()
            board.cards[index].isBlocked = false
            cancelReminder(for: cardId)
            handleRecurringTaskCompletion(board.cards[index])
        } else {
            if previousWasDone {
                board.cards[index].completedAt = nil
            }
            scheduleReminder(for: board.cards[index])
        }

        scheduleSave()
    }

    func moveCard(_ cardId: UUID, toColumn targetColumnId: UUID) {
        moveCard(cardId, toStage: targetColumnId)
    }

    private func handleRecurringTaskCompletion(_ card: Card) {
        guard let defaultIntakeStage,
              let newCard = card.createRecurringInstance(inStage: defaultIntakeStage.id)
        else {
            return
        }
        board.cards.append(newCard)
        scheduleReminder(for: newCard)
    }
}

extension BoardViewModel {
    func startCreatingCard(inStage stageId: UUID) {
        selectedCardId = nil
        creationTargetStageId = stageId
        isCreatingCard = true
    }

    func startCreatingCard(inColumn columnId: UUID) {
        startCreatingCard(inStage: columnId)
    }

    func quickCreateInDefaultStage() {
        guard let defaultIntakeStage else { return }
        startCreatingCard(inStage: defaultIntakeStage.id)
    }

    func selectCard(_ cardId: UUID) {
        isCreatingCard = false
        creationTargetStageId = nil
        selectedCardId = cardId
    }

    func closeSidePanel() {
        selectedCardId = nil
        isCreatingCard = false
        creationTargetStageId = nil
    }

    func addStage() -> UUID {
        let existingNames = Set(board.stages.map(\.name))
        let base = "New Stage"
        var candidate = base
        var suffix = 2
        while existingNames.contains(candidate) {
            candidate = "\(base) \(suffix)"
            suffix += 1
        }

        let stage = Stage(
            name: candidate,
            icon: "square.fill",
            color: .orange,
            position: board.stages.count
        )
        board.stages.append(stage)
        scheduleSave()
        return stage.id
    }

    func updateStage(_ stage: Stage) {
        guard let index = board.stages.firstIndex(where: { $0.id == stage.id }) else { return }
        var updated = stage
        updated.name = updated.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updated.name.isEmpty else { return }
        guard board.stages.allSatisfy({
            $0.id == updated.id || $0.name.localizedCaseInsensitiveCompare(updated.name) != .orderedSame
        }) else {
            errorMessage = "Stage names must be unique."
            return
        }

        if updated.isDoneStage {
            updated.isDefaultIntake = false
            updated.allowsManualCardCreation = false
        }

        if updated.isDefaultIntake {
            for stageIndex in board.stages.indices where board.stages[stageIndex].id != updated.id {
                board.stages[stageIndex].isDefaultIntake = false
            }
        }

        board.stages[index] = updated
        normalizeCardsForStageChanges()
        scheduleSave()
    }

    func setDefaultIntakeStage(_ stageId: UUID) {
        for index in board.stages.indices {
            let isTarget = board.stages[index].id == stageId
            board.stages[index].isDefaultIntake = isTarget && !board.stages[index].isDoneStage
        }
        scheduleSave()
    }

    func moveStages(fromOffsets source: IndexSet, toOffset destination: Int) {
        board.stages.move(fromOffsets: source, toOffset: destination)
        for index in board.stages.indices {
            board.stages[index].position = index
        }
        scheduleSave()
    }

    func deleteStage(_ stageId: UUID, replacementStageId: UUID) {
        guard board.stages.count > 1 else { return }
        guard let replacementStage = stage(withId: replacementStageId), replacementStage.id != stageId else { return }

        let deletedStageWasDefault = stage(withId: stageId)?.isDefaultIntake == true

        for index in board.cards.indices where board.cards[index].stageId == stageId {
            board.cards[index].stageId = replacementStageId
            normalizeCardState(&board.cards[index], stage: replacementStage)
        }

        board.stages.removeAll { $0.id == stageId }
        for index in board.stages.indices {
            board.stages[index].position = index
        }
        if deletedStageWasDefault {
            setDefaultIntakeStage(replacementStageId)
        } else {
            scheduleSave()
        }
    }

    func availableReplacementStages(excluding stageId: UUID) -> [Stage] {
        sortedStages.filter { $0.id != stageId }
    }

    func changeStorageFolder(to url: URL) async {
        do {
            let previousFolder = await StorageService.shared.currentStorageFolder
            try await StorageService.shared.changeStorageFolder(to: url)
            do {
                board = try await StorageService.shared.loadBoard()
                addDefaultChecklistToBlogCards()
            } catch {
                try? await StorageService.shared.changeStorageFolder(to: previousFolder)
                errorMessage = "Failed to load data from selected folder: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "Failed to change storage folder: \(error.localizedDescription)"
        }
    }

    func currentStorageFolder() async -> URL {
        await StorageService.shared.currentStorageFolder
    }

    private func normalizeCardsForStageChanges() {
        for index in board.cards.indices {
            normalizeCardState(&board.cards[index])
        }
    }

    private func normalizeCardState(_ card: inout Card, stage currentStage: Stage? = nil) {
        guard let resolvedStage = currentStage ?? stage(withId: card.stageId) else { return }
        if resolvedStage.isDoneStage {
            card.completedAt = card.completedAt ?? Date()
            card.isBlocked = false
        } else {
            card.completedAt = nil
        }
    }
}

struct WeeklyReviewData {
    let completedCards: [Card]
    let createdCards: [Card]
    let activeCards: [Card]
    let blockedCards: [Card]
    let overdueCards: [Card]
    let totalCards: Int
}
