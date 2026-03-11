import SwiftUI

@Observable
@MainActor
final class NotesViewModel {
    var store: NotesStore = NotesStore()
    var selectedNoteId: UUID?
    var searchText: String = ""
    var errorMessage: String?
    var showDeleteConfirmation: Bool = false
    var noteToDelete: UUID?

    private var debouncedSave: DebouncedSave?

    init() {
        debouncedSave = DebouncedSave { [weak self] in
            await self?.persistNotes()
        }
        Task {
            await loadNotes()
        }
    }

    // MARK: - Persistence

    func loadNotes() async {
        do {
            store = try await StorageService.shared.loadNotes()
        } catch {
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
            store = NotesStore()
        }
    }

    private func scheduleSave() {
        debouncedSave?.schedule()
    }

    private func persistNotes() async {
        do {
            try await StorageService.shared.saveNotes(store)
        } catch {
            errorMessage = "Failed to save notes: \(error.localizedDescription)"
        }
    }

    // MARK: - Filtered Notes

    var filteredNotes: [Note] {
        let sorted = store.notes.sorted { $0.updatedAt > $1.updatedAt }
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var selectedNote: Note? {
        guard let id = selectedNoteId else { return nil }
        return store.notes.first { $0.id == id }
    }

    // MARK: - CRUD

    func createNote() {
        let note = Note(title: "Untitled Note")
        store.notes.append(note)
        selectedNoteId = note.id
        scheduleSave()
    }

    func updateNote(_ note: Note) {
        guard let index = store.notes.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = note
        updated.updatedAt = Date()
        store.notes[index] = updated
        scheduleSave()
    }

    func confirmDeleteNote(_ noteId: UUID) {
        noteToDelete = noteId
        showDeleteConfirmation = true
    }

    func deleteNote() {
        guard let id = noteToDelete else { return }
        store.notes.removeAll { $0.id == id }
        if selectedNoteId == id {
            selectedNoteId = nil
        }
        noteToDelete = nil
        scheduleSave()
    }

    // MARK: - Import / Export

    func importNotes(from url: URL) async {
        do {
            store = try await StorageService.shared.importNotes(from: url)
            selectedNoteId = nil
        } catch {
            errorMessage = "Failed to import notes: \(error.localizedDescription)"
        }
    }

    func reloadFromStorage() async {
        await loadNotes()
    }
}
