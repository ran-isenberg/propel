import Foundation

actor StorageService {
    static let shared = StorageService()

    private static let storageFolderKey = "PropelStorageFolder"
    private static let bookmarkKey = "PropelStorageFolderBookmark"

    private var storageDir: URL
    private var boardFileURL: URL
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
                boardFileURL = url.appendingPathComponent("board.json")
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
        boardFileURL = storageDir.appendingPathComponent("board.json")
        notesFileURL = storageDir.appendingPathComponent("notes.json")
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

        // Resolve symlinks to prevent symlink attacks
        let resolvedFolder = newFolder.resolvingSymlinksInPath()
        guard resolvedFolder.isFileURL else { return }

        // Stop accessing old folder first
        stopAccessing()

        // Start accessing the new folder before any file operations
        let didStartAccess = resolvedFolder.startAccessingSecurityScopedResource()

        // Save security-scoped bookmark for persistent access across launches
        if let bookmarkData = try? resolvedFolder.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(bookmarkData, forKey: Self.bookmarkKey)
        }

        try fm.createDirectory(at: resolvedFolder, withIntermediateDirectories: true)

        let newBoardURL = resolvedFolder.appendingPathComponent("board.json")
        let newNotesURL = resolvedFolder.appendingPathComponent("notes.json")

        // Copy existing files to new location if they don't already exist there
        if fm.fileExists(atPath: boardFileURL.path), !fm.fileExists(atPath: newBoardURL.path) {
            try fm.copyItem(at: boardFileURL, to: newBoardURL)
        }
        if fm.fileExists(atPath: notesFileURL.path), !fm.fileExists(atPath: newNotesURL.path) {
            try fm.copyItem(at: notesFileURL, to: newNotesURL)
        }

        storageDir = resolvedFolder
        boardFileURL = newBoardURL
        notesFileURL = newNotesURL
        isAccessingSecurityScope = didStartAccess

        UserDefaults.standard.set(resolvedFolder.path, forKey: Self.storageFolderKey)
    }

    func resetStorageToDefault() throws {
        stopAccessing()
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let defaultDir = appSupport.appendingPathComponent("Propel", isDirectory: true)
        UserDefaults.standard.removeObject(forKey: Self.storageFolderKey)
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        storageDir = defaultDir
        boardFileURL = defaultDir.appendingPathComponent("board.json")
        notesFileURL = defaultDir.appendingPathComponent("notes.json")
        try ensureDirectoryExists()
    }

    /// Ensure the storage directory exists.
    func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }

    // MARK: - Board

    func loadBoard() throws -> Board {
        startAccessing()
        try ensureDirectoryExists()
        guard FileManager.default.fileExists(atPath: boardFileURL.path) else {
            let defaultBoard = Board()
            try saveBoard(defaultBoard)
            return defaultBoard
        }
        let data = try Data(contentsOf: boardFileURL)
        return try decoder.decode(Board.self, from: data)
    }

    func saveBoard(_ board: Board) throws {
        startAccessing()
        try ensureDirectoryExists()
        let data = try encoder.encode(board)
        try atomicWrite(data: data, to: boardFileURL)
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
