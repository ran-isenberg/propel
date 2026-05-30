import SwiftUI
import UserNotifications

@Observable
@MainActor
final class BoardViewModel {
    /// Number of board positions the app supports.
    static let slotCount = StorageService.slotCount
    private static let activeBoardIdKey = "PropelActiveBoardId"
    /// Pre-id active-position key, migrated once if present.
    private static let legacyActiveSlotKey = "PropelActiveBoardSlot"

    var board: Board = .init()
    var selectedCardId: UUID?
    var isCreatingCard: Bool = false
    var creationTargetColumnId: UUID?
    var errorMessage: String?

    // MARK: - Board Slots

    /// Ordered board ids defining positions 1...slotCount.
    private(set) var boardOrder: [UUID] = []
    /// The id of the board currently displayed (the active board follows its
    /// board across reorders).
    private(set) var activeBoardId: UUID?
    /// Display names for each position (1-based), empty/unnamed positions omitted.
    private(set) var slotNames: [Int: String] = [:]

    /// Card counts per workflow role summed across all boards (for the menu bar
    /// summary). Columns are user-defined per board, so the summary groups by
    /// role rather than by individual column.
    private(set) var aggregateRoleCounts = AggregateRoleCounts()
    /// Overdue cards summed across all boards.
    private(set) var aggregateOverdueCount: Int = 0

    // MARK: - Filters

    var filterLabel: UUID?
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

    // MARK: - Delivered Notifications

    var deliveredReminderCount: Int = 0

    private var debouncedSave: DebouncedSave?
    private var notificationCheckTask: Task<Void, Never>?
    private let storage: StorageService

    init(storage: StorageService = .shared) {
        self.storage = storage
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

    // MARK: - Persistence

    /// Load the manifest order and the active board.
    func loadBoard() async {
        do {
            boardOrder = try await storage.loadBoards().map(\.id)
            resolveActiveBoardId()
            if let id = activeBoardId {
                board = try await storage.loadBoard(id: id)
                addDefaultChecklistToCards()
            }
            await refreshSlotNames()
            await refreshBoardsSummary()
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
        guard activeBoardId != nil else { return }
        do {
            try await storage.saveBoard(board)
            await refreshBoardsSummary()
        } catch {
            errorMessage = "Failed to save board: \(error.localizedDescription)"
        }
    }

    // MARK: - Column Helpers

    var sortedColumns: [Column] {
        board.columns.sorted { $0.position < $1.position }
    }

    /// The column fulfilling a special workflow role on the active board.
    func column(for role: ColumnRole) -> Column? {
        board.column(for: role)
    }

    var intakeColumn: Column? { board.column(for: .intake) }
    var blockedColumn: Column? { board.column(for: .blocked) }
    var doneColumn: Column? { board.column(for: .done) }

    func cardsForColumn(_ column: Column) -> [Card] {
        var cards = board.cardsForColumn(column)
        if let labelId = filterLabel {
            cards = cards.filter { $0.labelId == labelId }
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
        if autoArchiveDays > 0, column.isDoneStage {
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
            if let doneColumn = column(for: .done),
               card.columnId == doneColumn.id
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
            if let doneColumn = column(for: .done),
               card.columnId == doneColumn.id { return false }
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

        // "In progress" = cards in any active working column, i.e. not intake,
        // not blocked, and not done.
        let activeColumnIds = Set(
            board.columns.filter { !$0.isDefaultIntake && !$0.isBlockedStage && !$0.isDoneStage }.map(\.id)
        )
        let inProgressCards = board.cards.filter { activeColumnIds.contains($0.columnId) }

        let overdueCards = board.cards.filter { card in
            guard let due = card.dueDate else { return false }
            if let doneColumn = column(for: .done),
               card.columnId == doneColumn.id { return false }
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
        aggregateOverdueCount + deliveredReminderCount
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
                try? await Task.sleep(for: .seconds(600))
                guard !Task.isCancelled else { return }
                await self?.checkDueDateNotifications()
            }
        }
    }

    func refreshDeliveredNotificationCount() async {
        guard Self.isRunningInApp else { return }
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        let reminderCount = delivered.count(where: { $0.request.identifier.hasPrefix("reminder-") })
        deliveredReminderCount = reminderCount
    }

    private func checkDueDateNotifications() async {
        guard Self.isRunningInApp else { return }
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today) ?? today

        for card in board.cards {
            guard let dueDate = card.dueDate else { continue }
            // Skip completed cards
            if let doneColumn = column(for: .done),
               card.columnId == doneColumn.id { continue }
            // Skip cards with user-configured reminders (handled by scheduleReminder)
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

    func scheduleReminder(for card: Card) {
        guard Self.isRunningInApp else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["reminder-\(card.id)"])

        guard card.reminder != .none,
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

    private func cancelReminder(for cardId: UUID) {
        guard Self.isRunningInApp else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["reminder-\(cardId)"])
    }

    // MARK: - Card CRUD

    func createCard(
        title: String,
        labelId: UUID,
        priority: Priority,
        description: String = "",
        dueDate: Date? = nil,
        isRecurring: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        reminder: ReminderOffset = .none,
        inColumn columnId: UUID
    ) {
        let labelDef = board.label(for: labelId)
        let checklist: [ChecklistItem] = labelDef.defaultChecklist.enumerated().map { i, title in
            ChecklistItem(title: title, position: i)
        }
        let card = Card(
            title: title,
            description: description,
            columnId: columnId,
            labelId: labelId,
            priority: priority,
            dueDate: dueDate,
            checklist: checklist,
            isRecurring: isRecurring,
            recurrenceRule: recurrenceRule,
            reminder: reminder
        )
        board.cards.append(card)
        isCreatingCard = false
        creationTargetColumnId = nil
        selectedCardId = card.id
        scheduleReminder(for: card)
        scheduleSave()
    }

    func addDefaultChecklistToCards() {
        // Reordering default items to match the built-in order is a one-time
        // migration. Running it on every load would silently undo any deliberate
        // reordering the user makes, so it is gated behind the schema version.
        let isMigrating = board.schemaVersion < Board.currentSchemaVersion
        var didModify = false
        for index in board.cards.indices {
            let labelDef = board.label(for: board.cards[index].labelId)
            guard !labelDef.defaultChecklist.isEmpty else { continue }

            let defaultChecklistItems = labelDef.defaultChecklist.enumerated().map { i, title in
                ChecklistItem(title: title, position: i)
            }
            let existing = Set(board.cards[index].checklist.map(\.title))
            let missing = defaultChecklistItems.filter { !existing.contains($0.title) }
            let defaultTitles = Set(defaultChecklistItems.map(\.title))

            // Whether the default items are out of their built-in relative order.
            let currentTitles = board.cards[index].checklist.map(\.title)
            let currentDefaultOrder = currentTitles.filter { defaultTitles.contains($0) }
            let expectedOrder = defaultChecklistItems.map(\.title).filter { existing.contains($0) }
            let needsReorder = currentDefaultOrder != expectedOrder

            if !missing.isEmpty || (needsReorder && isMigrating) {
                // Rebuild as: default items in built-in order, then custom items.
                // Triggered when items are missing (so new defaults land in the
                // right place) or, during a one-time migration, to normalize order.
                let customItems = board.cards[index].checklist.filter { !defaultTitles.contains($0.title) }
                var merged: [ChecklistItem] = []
                for defaultItem in defaultChecklistItems {
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
        // Persist the bumped version so the reorder migration does not run again.
        if isMigrating { board.schemaVersion = Board.currentSchemaVersion }
        if didModify || isMigrating { scheduleSave() }
    }

    func updateCard(_ card: Card) {
        guard let index = board.cards.firstIndex(where: { $0.id == card.id }) else { return }
        var updated = card
        updated.updatedAt = Date()
        board.cards[index] = updated
        scheduleReminder(for: updated)
        scheduleSave()
    }

    func deleteCard(_ cardId: UUID) {
        cancelReminder(for: cardId)
        board.cards.removeAll { $0.id == cardId }
        if selectedCardId == cardId { selectedCardId = nil }
        scheduleSave()
    }

    func clearCompletedCards() {
        guard let col = column(for: .done) else { return }
        let ids = Set(board.cards.filter { $0.columnId == col.id }.map(\.id))
        ids.forEach { cancelReminder(for: $0) }
        board.cards.removeAll { ids.contains($0.id) }
        if let selectedCardId, ids.contains(selectedCardId) { self.selectedCardId = nil }
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

        // Check if moving to the done column
        if let targetColumn = board.columns.first(where: { $0.id == targetColumnId }),
           targetColumn.isDoneStage
        {
            board.cards[index].completedAt = Date()
            cancelReminder(for: cardId)
            handleRecurringTaskCompletion(board.cards[index])
        } else {
            // If moving out of the done column, clear completedAt
            if let previousColumn = board.columns.first(where: { $0.id == previousColumnId }),
               previousColumn.isDoneStage
            {
                board.cards[index].completedAt = nil
            }
        }

        scheduleSave()
    }

    private func handleRecurringTaskCompletion(_ card: Card) {
        guard let intakeColumn = column(for: .intake),
              let newCard = card.createRecurringInstance(inColumn: intakeColumn.id)
        else {
            return
        }
        board.cards.append(newCard)
        scheduleReminder(for: newCard)
    }

    // MARK: - Card Context Menu Actions

    func changeCardPriority(_ cardId: UUID, to priority: Priority) {
        guard let index = board.cards.firstIndex(where: { $0.id == cardId }) else { return }
        board.cards[index].priority = priority
        board.cards[index].updatedAt = Date()
        scheduleSave()
    }

    func changeCardLabel(_ cardId: UUID, to labelId: UUID) {
        guard let index = board.cards.firstIndex(where: { $0.id == cardId }) else { return }
        board.cards[index].labelId = labelId
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
        guard let blockedColumn = column(for: .blocked) else { return }

        if card.columnId == blockedColumn.id {
            // Unblock: move to the first active working column, falling back to intake.
            let destination = sortedColumns.first { !$0.isProtected } ?? column(for: .intake)
            if let destination { moveCard(cardId, toColumn: destination.id) }
        } else {
            // Block: move to the Blocked column.
            moveCard(cardId, toColumn: blockedColumn.id)
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
}

// MARK: - Storage

extension BoardViewModel {
    func changeStorageFolder(to url: URL) async {
        do {
            let previousFolder = await storage.currentStorageFolder
            try await storage.changeStorageFolder(to: url)
            do {
                // Reload the manifest, order, and active board from the new location.
                boardOrder = try await storage.loadBoards().map(\.id)
                resolveActiveBoardId()
                if let id = activeBoardId {
                    board = try await storage.loadBoard(id: id)
                    addDefaultChecklistToCards()
                }
                await refreshSlotNames()
            } catch {
                // Loading failed — revert storage to prevent auto-save overwriting user files
                try? await storage.changeStorageFolder(to: previousFolder)
                errorMessage = "Failed to load data from selected folder: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "Failed to change storage folder: \(error.localizedDescription)"
        }
    }

    func currentStorageFolder() async -> URL {
        await storage.currentStorageFolder
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

/// Card counts grouped by workflow role, summed across all boards.
struct AggregateRoleCounts: Equatable {
    var intake = 0
    var active = 0
    var blocked = 0
    var done = 0
}

// MARK: - Board Slots

extension BoardViewModel {
    /// The 1-based position of the active board, or 1 if not yet resolved.
    var activeSlot: Int {
        guard let id = activeBoardId, let index = boardOrder.firstIndex(of: id) else { return 1 }
        return index + 1
    }

    /// Pick the active board id from persisted state, falling back to position 1.
    func resolveActiveBoardId() {
        let defaults = UserDefaults.standard
        // One-time migration from the position-based key.
        if defaults.string(forKey: Self.activeBoardIdKey) == nil,
           defaults.object(forKey: Self.legacyActiveSlotKey) != nil
        {
            let slot = defaults.integer(forKey: Self.legacyActiveSlotKey)
            if (1 ... boardOrder.count).contains(slot) {
                defaults.set(boardOrder[slot - 1].uuidString, forKey: Self.activeBoardIdKey)
            }
            defaults.removeObject(forKey: Self.legacyActiveSlotKey)
        }

        if let stored = defaults.string(forKey: Self.activeBoardIdKey),
           let id = UUID(uuidString: stored), boardOrder.contains(id)
        {
            activeBoardId = id
        } else {
            activeBoardId = boardOrder.first
        }
    }

    private func setActiveBoardId(_ id: UUID) {
        activeBoardId = id
        UserDefaults.standard.set(id.uuidString, forKey: Self.activeBoardIdKey)
    }

    /// Reset per-board UI state that should not leak across a slot change.
    private func resetTransientBoardState() {
        selectedCardId = nil
        isCreatingCard = false
        creationTargetColumnId = nil
        filterLabel = nil
        filterPriority = nil
        searchText = ""
        isSearching = false
        collapsedColumnIds = []
        showAttentionView = false
    }

    /// Reload position display names. The active position reflects the live
    /// in-memory name; others are read from disk.
    func refreshSlotNames() async {
        var names: [Int: String] = [:]
        for (index, id) in boardOrder.enumerated() {
            let position = index + 1
            if id == activeBoardId {
                names[position] = board.name
            } else if let name = await storage.boardName(id: id) {
                names[position] = name
            }
        }
        slotNames = names
    }

    /// Recompute the menu-bar summary across all boards. The active board is read
    /// from memory; the others are loaded from disk.
    func refreshBoardsSummary() async {
        var counts = AggregateRoleCounts()
        var overdue = 0
        for id in boardOrder {
            let summaryBoard: Board? = await (id == activeBoardId) ? board : (try? storage.loadBoard(id: id))
            guard let summaryBoard else { continue }
            for column in summaryBoard.columns {
                let cardCount = summaryBoard.cards.count(where: { $0.columnId == column.id })
                if column.isDefaultIntake {
                    counts.intake += cardCount
                } else if column.isBlockedStage {
                    counts.blocked += cardCount
                } else if column.isDoneStage {
                    counts.done += cardCount
                } else {
                    counts.active += cardCount
                }
            }
            overdue += summaryBoard.overdueCardCount
        }
        aggregateRoleCounts = counts
        aggregateOverdueCount = overdue
    }

    /// The board id at a 1-based position, if any.
    private func boardId(atPosition position: Int) -> UUID? {
        guard (1 ... boardOrder.count).contains(position) else { return nil }
        return boardOrder[position - 1]
    }

    /// Persist the current board, then switch to display the board at a position.
    func switchToPosition(_ position: Int) async {
        guard let id = boardId(atPosition: position), id != activeBoardId else { return }
        await persistBoard()
        setActiveBoardId(id)
        resetTransientBoardState()
        do {
            board = try await storage.loadBoard(id: id)
            addDefaultChecklistToCards()
        } catch {
            errorMessage = "Failed to load board: \(error.localizedDescription)"
        }
        scheduleNotificationCheck()
        await refreshDeliveredNotificationCount()
        await refreshSlotNames()
        await refreshBoardsSummary()
    }

    /// Reorder by swapping two positions. The active board is untouched, so it
    /// stays selected and its highlighted button simply moves.
    func swapPositions(_ a: Int, _ b: Int) async {
        guard a != b, (1 ... boardOrder.count).contains(a), (1 ... boardOrder.count).contains(b) else { return }
        boardOrder.swapAt(a - 1, b - 1)
        do {
            try await storage.saveManifest(StorageService.BoardsManifest(order: boardOrder))
        } catch {
            errorMessage = "Failed to reorder boards: \(error.localizedDescription)"
            return
        }
        await refreshSlotNames()
    }

    /// Whether `name` is free to use (case-insensitive) for the board with `id`.
    /// Empty names are always allowed (multiple unnamed boards are fine).
    private func isNameAvailable(_ name: String, excluding id: UUID?) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        for other in boardOrder where other != id {
            let existing = await other == activeBoardId ? board.name : (storage.boardName(id: other) ?? "")
            if existing.caseInsensitiveCompare(trimmed) == .orderedSame { return false }
        }
        return true
    }

    /// Rename the active board, blocking on a case-insensitive name collision.
    func renameActiveBoard(to newName: String) async {
        guard let id = activeBoardId else { return }
        await renameBoard(id: id, to: newName)
    }

    /// Rename a board by id, blocking on a case-insensitive name collision.
    func renameBoard(id: UUID, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard await isNameAvailable(trimmed, excluding: id) else {
            errorMessage = "A board named “\(trimmed)” already exists."
            return
        }
        if id == activeBoardId {
            board.name = trimmed
            scheduleSave()
        } else {
            do {
                var target = try await storage.loadBoard(id: id)
                target.name = trimmed
                target.updatedAt = Date()
                try await storage.saveBoard(target)
            } catch {
                errorMessage = "Failed to rename board: \(error.localizedDescription)"
                return
            }
        }
        await refreshSlotNames()
    }

    /// Import an external board file into a position (replacing whatever is there),
    /// blocking on a case-insensitive name collision with another board.
    func importBoard(from url: URL, intoPosition position: Int) async {
        guard let replacedId = boardId(atPosition: position) else { return }
        let imported: Board
        do {
            imported = try await storage.importBoard(from: url)
        } catch {
            errorMessage = "Failed to import board: \(error.localizedDescription)"
            return
        }
        guard await isNameAvailable(imported.name, excluding: replacedId) else {
            await storage.deleteBoardFile(id: imported.id)
            errorMessage = "A board named “\(imported.name)” already exists."
            return
        }
        await placeBoard(imported.id, atPosition: position, replacing: replacedId, makeActive: true)
    }

    /// Reset a position to a fresh empty board.
    func deleteBoard(atPosition position: Int) async {
        guard let replacedId = boardId(atPosition: position) else { return }
        let replacement = Board()
        do {
            try await storage.saveBoard(replacement)
        } catch {
            errorMessage = "Failed to delete board: \(error.localizedDescription)"
            return
        }
        await placeBoard(replacement.id, atPosition: position, replacing: replacedId, makeActive: replacedId == activeBoardId)
    }

    /// Wire a saved board into a position, removing the replaced board's file and
    /// updating the manifest. Reloads when the affected position is active.
    private func placeBoard(_ newId: UUID, atPosition position: Int, replacing oldId: UUID, makeActive: Bool) async {
        boardOrder[position - 1] = newId
        await storage.deleteBoardFile(id: oldId)
        do {
            try await storage.saveManifest(StorageService.BoardsManifest(order: boardOrder))
        } catch {
            errorMessage = "Failed to update boards: \(error.localizedDescription)"
        }
        if makeActive {
            setActiveBoardId(newId)
            resetTransientBoardState()
            do {
                board = try await storage.loadBoard(id: newId)
                addDefaultChecklistToCards()
            } catch {
                errorMessage = "Failed to load board: \(error.localizedDescription)"
            }
        }
        await refreshSlotNames()
        await refreshBoardsSummary()
    }
}

// MARK: - Label Management

extension BoardViewModel {
    func addLabel(name: String, colorName: String) {
        let label = LabelDefinition(name: name, colorName: colorName)
        board.labels.append(label)
        scheduleSave()
    }

    func updateLabel(_ labelId: UUID, name: String, colorName: String) {
        guard let index = board.labels.firstIndex(where: { $0.id == labelId }) else { return }
        board.labels[index].name = name
        board.labels[index].colorName = colorName
        scheduleSave()
    }

    func cardsUsingLabel(_ labelId: UUID) -> Int {
        board.cards.count(where: { $0.labelId == labelId })
    }

    func canDeleteLabel(_ labelId: UUID) -> Bool {
        cardsUsingLabel(labelId) == 0 && board.labels.count > 1
    }

    func deleteLabel(_ labelId: UUID) {
        guard canDeleteLabel(labelId) else { return }
        board.labels.removeAll { $0.id == labelId }
        scheduleSave()
    }
}

// MARK: - Column Management

extension BoardViewModel {
    /// Add a new plain working column just before the done column and return its id.
    @discardableResult
    func addColumn() -> UUID {
        let doneIndex = sortedColumns.firstIndex(where: \.isDoneStage) ?? board.columns.count
        let new = Column(name: "New Column", icon: "circle.dotted", color: .slate, position: doneIndex)
        var columns = sortedColumns
        columns.insert(new, at: min(doneIndex, columns.count))
        reindex(&columns)
        board.columns = columns
        scheduleSave()
        return new.id
    }

    /// Persist edits to an existing column (name, icon, color, sort). Protected
    /// role flags are preserved from the stored column and cannot be changed here.
    func updateColumn(_ column: Column) {
        guard let index = board.columns.firstIndex(where: { $0.id == column.id }) else { return }
        var updated = column
        updated.isDefaultIntake = board.columns[index].isDefaultIntake
        updated.isBlockedStage = board.columns[index].isBlockedStage
        updated.isDoneStage = board.columns[index].isDoneStage
        board.columns[index] = updated
        scheduleSave()
    }

    /// Reorder columns by SwiftUI move semantics, then renumber positions.
    func moveColumns(fromOffsets source: IndexSet, toOffset destination: Int) {
        var columns = sortedColumns
        columns.move(fromOffsets: source, toOffset: destination)
        reindex(&columns)
        board.columns = columns
        scheduleSave()
    }

    /// Protected columns (intake / blocked / done) cannot be deleted.
    func canDeleteColumn(_ columnId: UUID) -> Bool {
        guard let column = board.columns.first(where: { $0.id == columnId }) else { return false }
        return !column.isProtected
    }

    /// Columns that can receive cards from a column being deleted.
    func availableReplacementColumns(excluding columnId: UUID) -> [Column] {
        sortedColumns.filter { $0.id != columnId }
    }

    /// Delete a non-protected column, moving its cards to `replacementColumnId`.
    func deleteColumn(_ columnId: UUID, replacementColumnId: UUID) {
        guard canDeleteColumn(columnId),
              board.columns.contains(where: { $0.id == replacementColumnId })
        else { return }

        let movingToDone = board.columns.first(where: { $0.id == replacementColumnId })?.isDoneStage ?? false
        for index in board.cards.indices where board.cards[index].columnId == columnId {
            board.cards[index].columnId = replacementColumnId
            board.cards[index].updatedAt = Date()
            if movingToDone, board.cards[index].completedAt == nil {
                board.cards[index].completedAt = Date()
            }
        }

        var columns = sortedColumns.filter { $0.id != columnId }
        reindex(&columns)
        board.columns = columns
        collapsedColumnIds.remove(columnId)
        scheduleSave()
    }

    private func reindex(_ columns: inout [Column]) {
        for i in columns.indices {
            columns[i].position = i
        }
    }
}
