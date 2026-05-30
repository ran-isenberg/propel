import Foundation
@testable import Propel
import Testing

// MARK: - Helpers

/// A `StorageService` pointed at a unique temporary directory, isolated from the
/// app's real storage and from other tests.
private func makeTempStorage() throws -> (StorageService, URL) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("PropelTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return (StorageService(storageDirectory: dir), dir)
}

private let isoEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()

/// ISO8601 drops sub-second precision, so use a date truncated to whole seconds
/// when round-trip equality matters.
private func stableDate() -> Date {
    Date(timeIntervalSince1970: Double(Int(Date().timeIntervalSince1970)))
}

private func boardFileURL(_ dir: URL, _ id: UUID) -> URL {
    dir.appendingPathComponent("board-\(id.uuidString).json")
}

private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
}

// MARK: - Storage-Level Tests

struct MultiBoardStorageTests {
    @Test func migratesLegacyBoardJsonIntoManifest() async throws {
        let (storage, dir) = try makeTempStorage()
        let legacyURL = dir.appendingPathComponent("board.json")
        try isoEncoder.encode(Board(name: "Legacy")).write(to: legacyURL)

        let boards = try await storage.loadBoards()

        #expect(boards.count == 3)
        #expect(boards[0].name == "Legacy")
        #expect(boards[1].name.isEmpty)
        #expect(boards[2].name.isEmpty)
        // Legacy file gone; each board now stored by id; manifest present.
        #expect(!exists(legacyURL))
        #expect(exists(boardFileURL(dir, boards[0].id)))
        let manifest = await storage.loadManifest()
        #expect(manifest?.order == boards.map(\.id))
    }

    @Test func migratesUnreleasedSlotFilesPreservingOrderAndIds() async throws {
        let (storage, dir) = try makeTempStorage()
        let a = Board(name: "A"), b = Board(name: "B"), c = Board(name: "C")
        try isoEncoder.encode(a).write(to: dir.appendingPathComponent("board-1.json"))
        try isoEncoder.encode(b).write(to: dir.appendingPathComponent("board-2.json"))
        try isoEncoder.encode(c).write(to: dir.appendingPathComponent("board-3.json"))

        let boards = try await storage.loadBoards()

        #expect(boards.map(\.name) == ["A", "B", "C"])
        #expect(boards.map(\.id) == [a.id, b.id, c.id])
        #expect(!exists(dir.appendingPathComponent("board-1.json")))
        #expect(!exists(dir.appendingPathComponent("board-2.json")))
        #expect(exists(boardFileURL(dir, a.id)))
    }

    @Test func freshStorageCreatesThreeUnnamedBoards() async throws {
        let (storage, _) = try makeTempStorage()

        let boards = try await storage.loadBoards()

        #expect(boards.count == 3)
        #expect(boards.allSatisfy { $0.name.isEmpty })
        #expect(Board().name.isEmpty)
    }

    @Test func saveLoadRoundTrip() async throws {
        let (storage, _) = try makeTempStorage()
        let now = stableDate()
        var board = Board(name: "RT", createdAt: now, updatedAt: now)
        board.cards.append(Card(
            title: "Test",
            columnId: board.columns[0].id,
            labelId: LabelDefinition.videoId,
            createdAt: now,
            updatedAt: now
        ))

        try await storage.saveBoard(board)
        let decoded = try await storage.loadBoard(id: board.id)

        #expect(decoded == board)
    }

    @Test func boardNameReadsByIdOrNil() async throws {
        let (storage, _) = try makeTempStorage()
        let board = Board(name: "Named")
        try await storage.saveBoard(board)

        #expect(await storage.boardName(id: board.id) == "Named")
        #expect(await storage.boardName(id: UUID()) == nil)
    }

    @Test func importAssignsFreshIdEachTime() async throws {
        let (storage, dir) = try makeTempStorage()
        let source = Board(name: "Ext")
        let externalURL = dir.appendingPathComponent("external.json")
        try isoEncoder.encode(source).write(to: externalURL)

        let first = try await storage.importBoard(from: externalURL)
        let second = try await storage.importBoard(from: externalURL)

        #expect(first.name == "Ext")
        #expect(second.name == "Ext")
        #expect(first.id != source.id)
        #expect(second.id != source.id)
        #expect(first.id != second.id)
    }

    @Test func clearsLegacyDefaultNamesOnceForEmptyBoardsOnly() async throws {
        let (storage, _) = try makeTempStorage()
        let emptyDefault = Board(name: "Propel")          // empty + old default name
        var populatedDefault = Board(name: "Propel")      // old default name but has a card
        populatedDefault.cards.append(Card(
            title: "x",
            columnId: populatedDefault.columns[0].id,
            labelId: LabelDefinition.blogPostId
        ))
        let anotherEmpty = Board(name: "Propel")
        try await storage.saveBoard(emptyDefault)
        try await storage.saveBoard(populatedDefault)
        try await storage.saveBoard(anotherEmpty)
        try await storage.saveManifest(
            StorageService.BoardsManifest(order: [emptyDefault.id, populatedDefault.id, anotherEmpty.id])
        )

        let boards = try await storage.loadBoards()

        #expect(boards[0].name.isEmpty)        // empty "Propel" cleared
        #expect(boards[1].name == "Propel")    // populated "Propel" preserved
        #expect(boards[2].name.isEmpty)

        // Cleanup is one-time: a board later named "Propel" (even empty) is left alone.
        var renamed = try await storage.loadBoard(id: emptyDefault.id)
        renamed.name = "Propel"
        try await storage.saveBoard(renamed)
        let reloaded = try await storage.loadBoards()
        #expect(reloaded[0].name == "Propel")
    }

    @Test func importRejectsMalformedFile() async throws {
        let (storage, dir) = try makeTempStorage()
        let badURL = dir.appendingPathComponent("bad.json")
        try Data("not a board".utf8).write(to: badURL)

        await #expect(throws: (any Error).self) {
            _ = try await storage.importBoard(from: badURL)
        }
    }
}

// MARK: - View-Model-Level Tests

@MainActor
@Suite(.serialized)
struct MultiBoardViewModelTests {
    private static let activeBoardIdKey = "PropelActiveBoardId"

    /// Run `body` with the active-board UserDefaults key cleared and restored.
    private func withCleanActiveKey(_ body: () async throws -> Void) async rethrows {
        let original = UserDefaults.standard.object(forKey: Self.activeBoardIdKey)
        UserDefaults.standard.removeObject(forKey: Self.activeBoardIdKey)
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: Self.activeBoardIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.activeBoardIdKey)
            }
        }
        try await body()
    }

    @Test func switchToPositionResetsTransientStateAndPersistsActiveId() async throws {
        try await withCleanActiveKey {
            let (storage, _) = try makeTempStorage()
            let vm = BoardViewModel(storage: storage)
            await vm.loadBoard()
            vm.selectedCardId = UUID()
            vm.searchText = "query"
            vm.filterPriority = .high
            vm.collapsedColumnIds = [UUID()]

            await vm.switchToPosition(2)

            #expect(vm.activeSlot == 2)
            #expect(vm.activeBoardId == vm.boardOrder[1])
            #expect(vm.selectedCardId == nil)
            #expect(vm.searchText.isEmpty)
            #expect(vm.filterPriority == nil)
            #expect(vm.collapsedColumnIds.isEmpty)
            #expect(UserDefaults.standard.string(forKey: Self.activeBoardIdKey) == vm.boardOrder[1].uuidString)
        }
    }

    @Test func reorderIsConfigOnlyAndActiveFollowsBoard() async throws {
        try await withCleanActiveKey {
            let (storage, dir) = try makeTempStorage()
            let vm = BoardViewModel(storage: storage)
            await vm.loadBoard()
            await vm.renameActiveBoard(to: "Mine")
            let activeId = try #require(vm.activeBoardId)
            // Snapshot every board file's bytes before reordering.
            let before = try vm.boardOrder.reduce(into: [UUID: Data]()) { acc, id in
                acc[id] = try Data(contentsOf: boardFileURL(dir, id))
            }

            await vm.swapPositions(1, 2)

            // Active board unchanged; its position moved to 2.
            #expect(vm.activeBoardId == activeId)
            #expect(vm.activeSlot == 2)
            // Reorder only rewrote the manifest — board files are byte-identical.
            for (id, data) in before {
                #expect(exists(boardFileURL(dir, id)))
                #expect(try Data(contentsOf: boardFileURL(dir, id)) == data)
            }
            let manifest = await storage.loadManifest()
            #expect(manifest?.order == vm.boardOrder)
        }
    }

    @Test func renameBlocksCaseInsensitiveDuplicates() async throws {
        try await withCleanActiveKey {
            let (storage, _) = try makeTempStorage()
            let vm = BoardViewModel(storage: storage)
            await vm.loadBoard()
            let pos2Id = vm.boardOrder[1]

            await vm.renameActiveBoard(to: "Work")     // position 1 (active)
            await vm.renameBoard(id: pos2Id, to: "work") // collides, case-insensitive

            #expect(vm.errorMessage != nil)
            #expect(await storage.boardName(id: pos2Id)?.isEmpty == true)

            // A unique name and an empty name are both allowed.
            vm.errorMessage = nil
            await vm.renameBoard(id: pos2Id, to: "Personal")
            #expect(vm.errorMessage == nil)
            #expect(await storage.boardName(id: pos2Id) == "Personal")
            await vm.renameBoard(id: pos2Id, to: "")
            #expect(await storage.boardName(id: pos2Id)?.isEmpty == true)
        }
    }

    @Test func deleteReplacesPositionWithFreshEmptyBoard() async throws {
        try await withCleanActiveKey {
            let (storage, dir) = try makeTempStorage()
            let vm = BoardViewModel(storage: storage)
            await vm.loadBoard()
            await vm.renameActiveBoard(to: "Keep") // position 1
            let keptId = vm.boardOrder[0]
            let oldPos2Id = vm.boardOrder[1]

            await vm.deleteBoard(atPosition: 2)

            #expect(vm.boardOrder[1] != oldPos2Id)            // new id
            #expect(!exists(boardFileURL(dir, oldPos2Id)))     // old file removed
            #expect(await storage.boardName(id: vm.boardOrder[1])?.isEmpty == true)
            #expect(vm.boardOrder[0] == keptId)                // others untouched
            // Position 1 is active, so its renamed name lives in memory (debounced save).
            #expect(vm.board.name == "Keep")
        }
    }

    @Test func importIntoPositionReplacesAndBlocksOnNameCollision() async throws {
        try await withCleanActiveKey {
            let (storage, dir) = try makeTempStorage()
            let vm = BoardViewModel(storage: storage)
            await vm.loadBoard()

            // Successful import into position 2 becomes active.
            let importURL = dir.appendingPathComponent("import.json")
            try isoEncoder.encode(Board(name: "Imported")).write(to: importURL)
            let oldPos2Id = vm.boardOrder[1]
            await vm.importBoard(from: importURL, intoPosition: 2)
            #expect(vm.boardOrder[1] != oldPos2Id)
            #expect(!exists(boardFileURL(dir, oldPos2Id)))
            #expect(vm.activeSlot == 2)
            #expect(vm.board.name == "Imported")

            // Importing a file whose name collides with another board is blocked.
            let pos1Id = vm.boardOrder[0]
            let dupURL = dir.appendingPathComponent("dup.json")
            try isoEncoder.encode(Board(name: "Imported")).write(to: dupURL)
            let pos1Before = vm.boardOrder[0]
            await vm.importBoard(from: dupURL, intoPosition: 1)
            #expect(vm.errorMessage != nil)
            #expect(vm.boardOrder[0] == pos1Before)  // position unchanged
            #expect(pos1Id == pos1Before)
        }
    }
}
