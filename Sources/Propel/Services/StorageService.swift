import Foundation

actor StorageService {
    static let shared = StorageService()

    private static let storageFolderKey = "PropelStorageFolder"

    private var storageDir: URL
    private var boardFileURL: URL
    private var notesFileURL: URL

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
        if let savedPath = UserDefaults.standard.string(forKey: Self.storageFolderKey),
           !savedPath.isEmpty
        {
            storageDir = URL(fileURLWithPath: savedPath, isDirectory: true)
        } else {
            guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                fatalError("Application Support directory not found")
            }
            storageDir = appSupport.appendingPathComponent("Propel", isDirectory: true)
        }
        boardFileURL = storageDir.appendingPathComponent("board.json")
        notesFileURL = storageDir.appendingPathComponent("notes.json")
    }

    // MARK: - Storage Location

    var currentStorageFolder: URL {
        storageDir
    }

    func changeStorageFolder(to newFolder: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: newFolder, withIntermediateDirectories: true)

        let newBoardURL = newFolder.appendingPathComponent("board.json")
        let newNotesURL = newFolder.appendingPathComponent("notes.json")

        // Copy existing files to new location if they don't already exist there
        if fm.fileExists(atPath: boardFileURL.path), !fm.fileExists(atPath: newBoardURL.path) {
            try fm.copyItem(at: boardFileURL, to: newBoardURL)
        }
        if fm.fileExists(atPath: notesFileURL.path), !fm.fileExists(atPath: newNotesURL.path) {
            try fm.copyItem(at: notesFileURL, to: newNotesURL)
        }

        storageDir = newFolder
        boardFileURL = newBoardURL
        notesFileURL = newNotesURL

        UserDefaults.standard.set(newFolder.path, forKey: Self.storageFolderKey)
    }

    func resetStorageToDefault() throws {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory not found")
        }
        let defaultDir = appSupport.appendingPathComponent("Propel", isDirectory: true)
        UserDefaults.standard.removeObject(forKey: Self.storageFolderKey)
        storageDir = defaultDir
        boardFileURL = defaultDir.appendingPathComponent("board.json")
        notesFileURL = defaultDir.appendingPathComponent("notes.json")
    }

    /// Ensure the storage directory exists.
    func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
    }

    // MARK: - Board

    func loadBoard() throws -> Board {
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
        try ensureDirectoryExists()
        let data = try encoder.encode(board)
        try atomicWrite(data: data, to: boardFileURL)
    }

    // MARK: - Notes

    func loadNotes() throws -> NotesStore {
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
        try ensureDirectoryExists()
        let data = try encoder.encode(store)
        try atomicWrite(data: data, to: notesFileURL)
    }

    // MARK: - Import / Export

    func exportBoard(to url: URL) throws {
        let board = try loadBoard()
        let data = try encoder.encode(board)
        try data.write(to: url, options: .atomic)
    }

    func exportNotes(to url: URL) throws {
        let notes = try loadNotes()
        let data = try encoder.encode(notes)
        try data.write(to: url, options: .atomic)
    }

    func exportAll(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try exportBoard(to: directory.appendingPathComponent("board.json"))
        try exportNotes(to: directory.appendingPathComponent("notes.json"))
    }

    func importBoard(from url: URL) throws -> Board {
        let data = try Data(contentsOf: url)
        let board = try decoder.decode(Board.self, from: data)
        try saveBoard(board)
        return board
    }

    func importNotes(from url: URL) throws -> NotesStore {
        let data = try Data(contentsOf: url)
        let store = try decoder.decode(NotesStore.self, from: data)
        try saveNotes(store)
        return store
    }

    // MARK: - Atomic Write with Backup

    private func atomicWrite(data: Data, to targetURL: URL) throws {
        let fileManager = FileManager.default
        let directory = targetURL.deletingLastPathComponent()
        let tempURL = directory.appendingPathComponent(UUID().uuidString + ".tmp")

        try data.write(to: tempURL, options: .atomic)

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
