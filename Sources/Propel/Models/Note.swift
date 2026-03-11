import Foundation

struct Note: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
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
