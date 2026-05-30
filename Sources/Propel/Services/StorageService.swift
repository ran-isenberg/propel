import Foundation

actor StorageService {
    static let shared = StorageService()

    /// Number of board positions the app supports.
    static let slotCount = 3
    /// Manifest holding the ordered list of board ids (positions 1...slotCount).
    private static let manifestFileName = "boards.json"
    /// Pre-multi-board single-board filename, migrated on first load.
    private static let legacyBoardFileName = "board.json"

    private static let storageFolderKey = "PropelStorageFolder"
    private static let bookmarkKey = "PropelStorageFolderBookmark"

    private var storageDir: URL
    private var notesFileURL: URL
    private var isAccessingSecurityScope = false

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {
        // Try to restore from security-scoped bookmark first
        if let bookmarkData = UserDefaults.standard.data(forKey: Self.bookmarkKey) {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if isStale {
                    // Bookmark is stale, try to renew it
                    if let renewed = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                        UserDefaults.standard.set(renewed, forKey: Self.bookmarkKey)
                    }
                }
                storageDir = url
                notesFileURL = url.appendingPathComponent("notes.json")
                return
            }
        }

        // Fall back to saved path (migration from pre-sandbox)
        if let savedPath = UserDefaults.standard.string(forKey: Self.storageFolderKey),
           !savedPath.isEmpty
        {
            storageDir = URL(fileURLWithPath: savedPath, isDirectory: true)
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            storageDir = appSupport.appendingPathComponent("Propel", isDirectory: true)
        }
        notesFileURL = storageDir.appendingPathComponent("notes.json")
    }

    /// Test-only initializer that points storage at a specific directory,
    /// skipping the security-scoped bookmark / UserDefaults bootstrap.
    init(storageDirectory: URL) {
        storageDir = storageDirectory
        notesFileURL = storageDirectory.appendingPathComponent("notes.json")
    }

    // MARK: - Board File URLs

    /// A board is stored at `board-<uuid>.json`, keyed by its stable id, so files
    /// are never renamed when a board is renamed or reordered.
    private func boardFileURL(id: UUID) -> URL {
        storageDir.appendingPathComponent("board-\(id.uuidString).json")
    }

    private var manifestFileURL: URL {
        storageDir.appendingPathComponent(Self.manifestFileName)
    }

    private var legacyBoardFileURL: URL {
        storageDir.appendingPathComponent(Self.legacyBoardFileName)
    }

    /// Old position-named file from the unreleased slot scheme (migration only).
    private func legacySlotFileURL(slot: Int) -> URL {
        storageDir.appendingPathComponent("board-\(slot).json")
    }

    // MARK: - Security-Scoped Access

    /// Begin accessing the security-scoped storage folder. Call before file operations on user-selected folders.
    func startAccessing() {
        if !isAccessingSecurityScope, storageDir.startAccessingSecurityScopedResource() {
            isAccessingSecurityScope = true
        }
    }

    /// Stop accessing the security-scoped storage folder.
    func stopAccessing() {
        if isAccessingSecurityScope {
            storageDir.stopAccessingSecurityScopedResource()
            isAccessingSecurityScope = false
        }
    }

    // MARK: - Storage Location

    var currentStorageFolder: URL {
        storageDir
    }

    func changeStorageFolder(to newFolder: URL) throws {
        let fm = FileManager.default

        guard newFolder.isFileURL else { return }

        // Stop accessing old folder first
        stopAccessing()

        // Start accessing the new folder before any file operations.
        // Must use the original URL from NSOpenPanel — resolving symlinks
        // creates a new URL that loses the security scope grant.
        let didStartAccess = newFolder.startAccessingSecurityScopedResource()

        // Save security-scoped bookmark for persistent access across launches
        if let bookmarkData = try? newFolder.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(bookmarkData, forKey: Self.bookmarkKey)
        }

        try fm.createDirectory(at: newFolder, withIntermediateDirectories: true)

        // Copy existing data files to the new location if not already present there.
        // Board files are named board-<uuid>.json, so discover them dynamically.
        let boardFileNames = (try? fm.contentsOfDirectory(atPath: storageDir.path))?
            .filter { $0.hasPrefix("board-") && $0.hasSuffix(".json") } ?? []
        let fileNames = boardFileNames
            + [Self.manifestFileName, Self.legacyBoardFileName, "notes.json"]
        for fileName in fileNames {
            let source = storageDir.appendingPathComponent(fileName)
            let destination = newFolder.appendingPathComponent(fileName)
            if fm.fileExists(atPath: source.path), !fm.fileExists(atPath: destination.path) {
                try fm.copyItem(at: source, to: destination)
            }
        }

        storageDir = newFolder
        notesFileURL = newFolder.appendingPathComponent("notes.json")
        isAccessingSecurityScope = didStartAccess

        UserDefaults.standard.set(newFolder.path, forKey: Self.storageFolderKey)
    }

    func resetStorageToDefault() throws {
        stopAccessing()
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let defaultDir = appSupport.appendingPathComponent("Propel", isDirectory: true)
        UserDefaults.standard.removeObject(forKey: Self.storageFolderKey)
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        storageDir = defaultDir
        notesFileURL = defaultDir.appendingPathComponent("notes.json")
        try ensureDirectoryExists()
    }

    /// Ensure the storage directory exists.
    func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }

    // MARK: - Board

    /// Ordered list of board ids defining positions 1...slotCount.
    struct BoardsManifest: Codable {
        var order: [UUID]
        /// One-time marker that legacy default-named ("Propel") empty boards have
        /// been cleared in this data folder. Absent in older/migrated manifests.
        var didClearDefaultNames: Bool?
    }

    /// Minimal projection used to read a board's display name without decoding
    /// the whole board.
    private struct BoardNameOnly: Decodable {
        let name: String
    }

    // MARK: Manifest

    func loadManifest() -> BoardsManifest? {
        guard let data = try? Data(contentsOf: manifestFileURL),
              let manifest = try? decoder.decode(BoardsManifest.self, from: data) else {
            return nil
        }
        return manifest
    }

    func saveManifest(_ manifest: BoardsManifest) throws {
        startAccessing()
        try ensureDirectoryExists()
        let data = try encoder.encode(manifest)
        try atomicWrite(data: data, to: manifestFileURL)
    }

    // MARK: Boards

    /// Load all boards in manifest order, running first-time migration when no
    /// manifest exists yet.
    func loadBoards() throws -> [Board] {
        startAccessing()
        try ensureDirectoryExists()

        var manifest = try loadManifest() ?? migrateToManifest()
        var boards: [Board] = []
        var manifestChanged = false
        for (index, id) in manifest.order.enumerated() {
            if let board = try loadBoardIfPresent(id: id) {
                boards.append(board)
            } else {
                // A referenced file went missing; substitute a fresh empty board.
                let replacement = Board()
                try saveBoard(replacement)
                manifest.order[index] = replacement.id
                boards.append(replacement)
                manifestChanged = true
            }
        }

        // One-time cleanup: boards created under the old default name "Propel"
        // that are still empty (no cards) become unnamed, matching the behavior
        // where empty boards have no name. Per-folder flag so a board the user
        // later names "Propel" is left alone.
        if manifest.didClearDefaultNames != true {
            for index in boards.indices where boards[index].name == "Propel" && boards[index].cards.isEmpty {
                boards[index].name = ""
                try saveBoard(boards[index])
            }
            manifest.didClearDefaultNames = true
            manifestChanged = true
        }

        if manifestChanged { try saveManifest(manifest) }
        return boards
    }

    func loadBoard(id: UUID) throws -> Board {
        let data = try Data(contentsOf: boardFileURL(id: id))
        return try decoder.decode(Board.self, from: data)
    }

    private func loadBoardIfPresent(id: UUID) throws -> Board? {
        let url = boardFileURL(id: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(Board.self, from: try Data(contentsOf: url))
    }

    func saveBoard(_ board: Board) throws {
        startAccessing()
        try ensureDirectoryExists()
        let data = try encoder.encode(board)
        try atomicWrite(data: data, to: boardFileURL(id: board.id))
    }

    func deleteBoardFile(id: UUID) {
        try? FileManager.default.removeItem(at: boardFileURL(id: id))
    }

    /// The display name stored for a board id, or nil if the file is missing.
    func boardName(id: UUID) -> String? {
        guard let data = try? Data(contentsOf: boardFileURL(id: id)),
              let summary = try? decoder.decode(BoardNameOnly.self, from: data) else {
            return nil
        }
        return summary.name
    }

    /// Decode an external board file and store it as a fresh board (new id, so it
    /// can't collide with an existing board). The caller wires it into a position.
    func importBoard(from externalURL: URL) throws -> Board {
        let data = try Data(contentsOf: externalURL)
        var board = try decoder.decode(Board.self, from: data)
        board.id = UUID()
        try saveBoard(board)
        return board
    }

    // MARK: Migration

    /// Build the initial manifest from whatever board files already exist, then
    /// remove the obsolete position-named / legacy files.
    private func migrateToManifest() throws -> BoardsManifest {
        let fm = FileManager.default
        var boards: [Board] = []
        var obsolete: [URL] = []

        // Unreleased slot scheme: board-1/2/3.json.
        for slot in 1...Self.slotCount {
            let url = legacySlotFileURL(slot: slot)
            if fm.fileExists(atPath: url.path), let board = try? decoder.decode(Board.self, from: Data(contentsOf: url)) {
                boards.append(board)
                obsolete.append(url)
            }
        }
        // Pre-multi-board single board.json.
        if boards.isEmpty, fm.fileExists(atPath: legacyBoardFileURL.path),
           let board = try? decoder.decode(Board.self, from: Data(contentsOf: legacyBoardFileURL)) {
            boards.append(board)
            obsolete.append(legacyBoardFileURL)
        }
        // Pad up to slotCount with fresh empty boards.
        while boards.count < Self.slotCount { boards.append(Board()) }

        for board in boards { try saveBoard(board) }
        let manifest = BoardsManifest(order: boards.map(\.id))
        try saveManifest(manifest)
        for url in obsolete { try? fm.removeItem(at: url) }
        return manifest
    }

    // MARK: - Notes

    func loadNotes() throws -> NotesStore {
        startAccessing()
        try ensureDirectoryExists()
        guard FileManager.default.fileExists(atPath: notesFileURL.path) else {
            let store = NotesStore()
            try saveNotes(store)
            return store
        }
        let data = try Data(contentsOf: notesFileURL)
        return try decoder.decode(NotesStore.self, from: data)
    }

    func saveNotes(_ store: NotesStore) throws {
        startAccessing()
        try ensureDirectoryExists()
        let data = try encoder.encode(store)
        try atomicWrite(data: data, to: notesFileURL)
    }

    // MARK: - Atomic Write with Backup

    private func atomicWrite(data: Data, to targetURL: URL) throws {
        let fileManager = FileManager.default
        let directory = targetURL.deletingLastPathComponent()
        let tempURL = directory.appendingPathComponent(UUID().uuidString + ".tmp")

        try data.write(to: tempURL, options: .atomic)
        defer { try? fileManager.removeItem(at: tempURL) }

        if fileManager.fileExists(atPath: targetURL.path) {
            let backupURL = targetURL.appendingPathExtension("backup")
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.copyItem(at: targetURL, to: backupURL)
            _ = try fileManager.replaceItemAt(targetURL, withItemAt: tempURL)
        } else {
            try fileManager.moveItem(at: tempURL, to: targetURL)
        }
    }
}
