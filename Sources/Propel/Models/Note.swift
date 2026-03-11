import Foundation

struct Note: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var content: String
    var rtfData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        rtfData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.rtfData = rtfData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct NotesStore: Codable, Equatable, Sendable {
    var notes: [Note]

    init(notes: [Note] = []) {
        self.notes = notes
    }
}
