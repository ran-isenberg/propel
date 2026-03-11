import SwiftUI
import UserNotifications

@Observable
@MainActor
final class BoardViewModel {
    var board: Board = .init()
    var selectedCardId: UUID?
    var isCreatingCard: Bool = false
    var creationTargetColumnId: UUID?
    var errorMessage: String?

    // MARK: - Filters

    var filterLabel: Label?
    var filterPriority: Priority?
    var isFilterActive: Bool {
        filterLabel != nil || filterPriority != nil
    }

    // MARK: - Search

    var searchText: String = ""
    var isSearching: Bool = false

    // MARK: - Collapsible Columns

    var collapsedColumnIds: Set<UUID> = []

    // MARK: - Auto-Archive

    var autoArchiveDays: Int = 7

    // MARK: - Done-First Toggle

    var showDoneFirst: Bool = false

    // MARK: - Attention View

    var showAttentionView: Bool = false

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
        }
    }

    // MARK: - Persistence

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

    private func scheduleSave() {
        board.updatedAt = Date()
        debouncedSave?.schedule()
    }

    private func persistBoard() async {
        do {
            try await StorageService.shared.saveBoard(board)
        } catch {
            errorMessage = "Failed to save board: \(error.localizedDescription)"
        }
    }

    // MARK: - Column Helpers

    var sortedColumns: [Column] {
        board.columns.sorted { $0.position < $1.position }
    }

    func column(for status: ColumnStatus) -> Column? {
        board.columns.first { $0.status == status }
    }

    func cardsForColumn(_ column: Column) -> [Card] {
        var cards = board.cardsForColumn(column)
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
        // Auto-archive: hide completed cards older than N days
        if autoArchiveDays > 0, column.status == .completed {
            let cutoff = Calendar.current.date(byAdding: .day, value: -autoArchiveDays, to: Date()) ?? Date()
            cards = cards.filter { card in
                guard let completedAt = card.completedAt else { return true }
                return completedAt > cutoff
            }
        }
        return cards
    }

    func clearFilters() {
        filterLabel = nil
        filterPriority = nil
    }

    // MARK: - Search

    var searchResults: [Card] {
        guard !searchText.isEmpty else { return [] }
        return board.cards.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    func toggleSearch() {
        isSearching.toggle()
        if !isSearching {
            searchText = ""
        }
    }

    // MARK: - Collapsible Columns

    func toggleColumnCollapsed(_ columnId: UUID) {
        if collapsedColumnIds.contains(columnId) {
            collapsedColumnIds.remove(columnId)
        } else {
            collapsedColumnIds.insert(columnId)
        }
    }

    func isColumnCollapsed(_ columnId: UUID) -> Bool {
        collapsedColumnIds.contains(columnId)
    }

    // MARK: - Column Sort Configuration

    func updateColumnSort(_ columnId: UUID, sortBy: [SortField]) {
        guard let index = board.columns.firstIndex(where: { $0.id == columnId }) else { return }
        board.columns[index].sortBy = sortBy
        scheduleSave()
    }

    // MARK: - Attention View

    var attentionCards: [Card] {
        let now = Date()
        let calendar = Calendar.current
        let soonThreshold = calendar.date(byAdding: .day, value: 3, to: now) ?? now

        return board.cards.filter { card in
            // Exclude completed cards
            if let completedColumn = column(for: .completed),
               card.columnId == completedColumn.id
            {
                return false
            }
            // Overdue
            if let due = card.dueDate, due < now { return true }
            // Due soon (within 3 days)
            if let due = card.dueDate, due <= soonThreshold { return true }
            // Blocked
            if let blockedColumn = column(for: .blocked),
               card.columnId == blockedColumn.id { return true }
            return false
        }.sorted { a, b in
            // Overdue first, then due soon, then blocked
            let aOverdue = a.dueDate.map { $0 < now } ?? false
            let bOverdue = b.dueDate.map { $0 < now } ?? false
            if aOverdue != bOverdue { return aOverdue }
            return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
        }
    }

    var overdueCount: Int {
        let now = Date()
        return board.cards.count(where: { card in
            guard let due = card.dueDate else { return false }
            if let completedColumn = column(for: .completed),
               card.columnId == completedColumn.id { return false }
            return due < now
        })
    }

    var blockedCount: Int {
        guard let blockedColumn = column(for: .blocked) else { return 0 }
        return board.cards.count(where: { $0.columnId == blockedColumn.id })
    }

    // MARK: - Weekly Review

    var weeklyReviewData: WeeklyReviewData {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        let completedThisWeek = board.cards.filter { card in
            guard let completedAt = card.completedAt else { return false }
            return completedAt >= weekAgo
        }

        let createdThisWeek = board.cards.filter { $0.createdAt >= weekAgo }

        let inProgressCards: [Card] = if let inProgressColumn = column(for: .inProgress) {
            board.cards.filter { $0.columnId == inProgressColumn.id }
        } else {
            []
        }

        let overdueCards = board.cards.filter { card in
            guard let due = card.dueDate else { return false }
            if let completedColumn = column(for: .completed),
               card.columnId == completedColumn.id { return false }
            return due < now
        }

        return WeeklyReviewData(
            completedCards: completedThisWeek,
            createdCards: createdThisWeek,
            inProgressCards: inProgressCards,
            overdueCards: overdueCards,
            totalCards: board.cards.count
        )
    }

    // MARK: - Menu Bar Badge

    var menuBarBadgeCount: Int {
        overdueCount + blockedCount
    }

    // MARK: - Notifications

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
                try? await Task.sleep(for: .seconds(3_600))
                guard !Task.isCancelled else { return }
                await self?.checkDueDateNotifications()
            }
        }
    }

    private func checkDueDateNotifications() async {
        guard Self.isRunningInApp else { return }
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now

        for card in board.cards {
            guard let dueDate = card.dueDate else { continue }
            if let completedColumn = column(for: .completed),
               card.columnId == completedColumn.id { continue }

            if dueDate < now {
                await sendNotification(title: "Overdue", body: "\"\(card.title)\" is past due", id: "overdue-\(card.id)")
            } else if dueDate <= tomorrow {
                await sendNotification(title: "Due Soon", body: "\"\(card.title)\" is due tomorrow", id: "due-soon-\(card.id)")
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

    // MARK: - Card CRUD

    private static let blogPostDefaultChecklist: [ChecklistItem] = [
        ChecklistItem(title: "PR", position: 0),
        ChecklistItem(title: "Merge", position: 1),
        ChecklistItem(title: "GA", position: 2),
        ChecklistItem(title: "LinkedIn", position: 3),
        ChecklistItem(title: "X", position: 4),
        ChecklistItem(title: "Heroes", position: 5),
    ]

    func createCard(title: String, label: Label, priority: Priority, description: String = "", dueDate: Date? = nil, inColumn columnId: UUID) {
        let checklist = label == .blogPost ? Self.blogPostDefaultChecklist : []
        let card = Card(
            title: title,
            description: description,
            columnId: columnId,
            label: label,
            priority: priority,
            dueDate: dueDate,
            checklist: checklist
        )
        board.cards.append(card)
        isCreatingCard = false
        creationTargetColumnId = nil
        selectedCardId = card.id
        scheduleSave()
    }

    func addDefaultChecklistToBlogCards() {
        var didModify = false
        for index in board.cards.indices where board.cards[index].label == .blogPost {
            let existing = Set(board.cards[index].checklist.map(\.title))
            let missing = Self.blogPostDefaultChecklist.filter { !existing.contains($0.title) }
            if !missing.isEmpty {
                let startPos = (board.cards[index].checklist.map(\.position).max() ?? -1) + 1
                let newItems = missing.enumerated().map { offset, item in
                    ChecklistItem(title: item.title, position: startPos + offset)
                }
                board.cards[index].checklist.append(contentsOf: newItems)
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
        board.cards[index] = updated
        scheduleSave()
    }

    func deleteCard(_ cardId: UUID) {
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
        copy.checklist = original.checklist.map {
            ChecklistItem(id: UUID(), title: $0.title, isCompleted: false, position: $0.position)
        }
        board.cards.append(copy)
        scheduleSave()
    }

    // MARK: - Card Movement

    func moveCard(_ cardId: UUID, toColumn targetColumnId: UUID) {
        guard let index = board.cards.firstIndex(where: { $0.id == cardId }) else { return }
        let previousColumnId = board.cards[index].columnId

        // Don't do anything if dropping in the same column
        guard previousColumnId != targetColumnId else { return }

        board.cards[index].columnId = targetColumnId
        board.cards[index].updatedAt = Date()

        // Check if moving to Completed column
        if let targetColumn = board.columns.first(where: { $0.id == targetColumnId }),
           targetColumn.status == .completed
        {
            board.cards[index].completedAt = Date()
            handleRecurringTaskCompletion(board.cards[index])
        } else {
            // If moving out of Completed, clear completedAt
            if let previousColumn = board.columns.first(where: { $0.id == previousColumnId }),
               previousColumn.status == .completed
            {
                board.cards[index].completedAt = nil
            }
        }

        scheduleSave()
    }

    private func handleRecurringTaskCompletion(_ card: Card) {
        guard let backlogColumn = column(for: .backlog),
              let newCard = card.createRecurringInstance(inColumn: backlogColumn.id)
        else {
            return
        }
        board.cards.append(newCard)
    }

    // MARK: - Card Context Menu Actions

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
        scheduleSave()
    }

    func toggleCardBlocked(_ cardId: UUID) {
        guard let index = board.cards.firstIndex(where: { $0.id == cardId }) else { return }
        let card = board.cards[index]
        if let blockedColumn = column(for: .blocked),
           let inProgressColumn = column(for: .inProgress)
        {
            if card.columnId == blockedColumn.id {
                // Unblock: move to In Progress
                moveCard(cardId, toColumn: inProgressColumn.id)
            } else {
                // Block: move to Blocked
                moveCard(cardId, toColumn: blockedColumn.id)
            }
        }
    }

    // MARK: - Side Panel

    func startCreatingCard(inColumn columnId: UUID) {
        selectedCardId = nil
        creationTargetColumnId = columnId
        isCreatingCard = true
    }

    func selectCard(_ cardId: UUID) {
        isCreatingCard = false
        creationTargetColumnId = nil
        selectedCardId = cardId
    }

    func closeSidePanel() {
        selectedCardId = nil
        isCreatingCard = false
        creationTargetColumnId = nil
    }

    var selectedCard: Card? {
        guard let id = selectedCardId else { return nil }
        return board.cards.first { $0.id == id }
    }

    var showSidePanel: Bool {
        selectedCardId != nil || isCreatingCard
    }

    // MARK: - Storage

    func changeStorageFolder(to url: URL) async {
        do {
            try await StorageService.shared.changeStorageFolder(to: url)
            // Reload from new location
            board = try await StorageService.shared.loadBoard()
        } catch {
            errorMessage = "Failed to change storage: \(error.localizedDescription)"
        }
    }

    func currentStorageFolder() async -> URL {
        await StorageService.shared.currentStorageFolder
    }
}

// MARK: - Weekly Review Data

struct WeeklyReviewData {
    let completedCards: [Card]
    let createdCards: [Card]
    let inProgressCards: [Card]
    let overdueCards: [Card]
    let totalCards: Int
}
