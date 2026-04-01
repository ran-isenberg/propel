import Foundation
@testable import Propel
import Testing

// MARK: - NotesViewModel Tests

@MainActor
struct NotesViewModelTests {
    private func makeViewModel() -> NotesViewModel {
        let vm = NotesViewModel()
        vm.store = NotesStore()
        return vm
    }

    @Test func createNoteAddsToStore() {
        let vm = makeViewModel()
        vm.createNote()
        #expect(vm.store.notes.count == 1)
        #expect(vm.store.notes[0].title == "Untitled Note")
        #expect(vm.selectedNoteId == vm.store.notes[0].id)
    }

    @Test func createMultipleNotes() {
        let vm = makeViewModel()
        vm.createNote()
        vm.createNote()
        vm.createNote()
        #expect(vm.store.notes.count == 3)
    }

    @Test func updateNoteChangesContent() {
        let vm = makeViewModel()
        vm.createNote()
        var note = vm.store.notes[0]
        note.title = "Mac Setup"
        note.content = "brew install node"
        vm.updateNote(note)
        #expect(vm.store.notes[0].title == "Mac Setup")
        #expect(vm.store.notes[0].content == "brew install node")
    }

    @Test func deleteNoteRemovesFromStore() {
        let vm = makeViewModel()
        vm.createNote()
        let noteId = vm.store.notes[0].id
        vm.confirmDeleteNote(noteId)
        #expect(vm.showDeleteConfirmation == true)
        #expect(vm.noteToDelete == noteId)
        vm.deleteNote()
        #expect(vm.store.notes.isEmpty)
        #expect(vm.selectedNoteId == nil)
    }

    @Test func deleteNonSelectedNoteKeepsSelection() {
        let vm = makeViewModel()
        vm.createNote()
        vm.createNote()
        let firstId = vm.store.notes[0].id
        let secondId = vm.store.notes[1].id
        vm.selectedNoteId = firstId
        vm.confirmDeleteNote(secondId)
        vm.deleteNote()
        #expect(vm.store.notes.count == 1)
        #expect(vm.selectedNoteId == firstId)
    }

    @Test func searchByTitle() {
        let vm = makeViewModel()
        vm.createNote()
        var note = vm.store.notes[0]
        note.title = "Mac Setup Script"
        note.content = "Some content"
        vm.updateNote(note)
        vm.createNote()
        var note2 = vm.store.notes[1]
        note2.title = "API Reference"
        note2.content = "Other content"
        vm.updateNote(note2)

        vm.searchText = "Mac"
        #expect(vm.filteredNotes.count == 1)
        #expect(vm.filteredNotes[0].title == "Mac Setup Script")
    }

    @Test func searchByContent() {
        let vm = makeViewModel()
        vm.createNote()
        var note = vm.store.notes[0]
        note.title = "Setup"
        note.content = "brew install node\nbrew install python"
        vm.updateNote(note)
        vm.createNote()
        var note2 = vm.store.notes[1]
        note2.title = "Other"
        note2.content = "unrelated stuff"
        vm.updateNote(note2)

        vm.searchText = "brew"
        #expect(vm.filteredNotes.count == 1)
        #expect(vm.filteredNotes[0].title == "Setup")
    }

    @Test func searchIsCaseInsensitive() {
        let vm = makeViewModel()
        vm.createNote()
        var note = vm.store.notes[0]
        note.title = "UPPERCASE"
        note.content = "some MIXED content"
        vm.updateNote(note)

        vm.searchText = "uppercase"
        #expect(vm.filteredNotes.count == 1)

        vm.searchText = "mixed"
        #expect(vm.filteredNotes.count == 1)
    }

    @Test func emptySearchReturnsAll() {
        let vm = makeViewModel()
        vm.createNote()
        vm.createNote()
        vm.searchText = ""
        #expect(vm.filteredNotes.count == 2)
    }

    @Test func filteredNotesSortedByUpdatedAt() {
        let vm = makeViewModel()
        vm.createNote()
        vm.createNote()
        // Update the first note so it has a newer updatedAt
        var older = vm.store.notes[0]
        older.title = "Older"
        vm.updateNote(older)
        var newer = vm.store.notes[1]
        newer.title = "Newer"
        vm.updateNote(newer)
        // The "Newer" note was updated last, so it should appear first
        let filtered = vm.filteredNotes
        #expect(filtered[0].title == "Newer")
    }

    @Test func selectedNoteReturnsCorrectNote() {
        let vm = makeViewModel()
        vm.createNote()
        let noteId = vm.store.notes[0].id
        vm.selectedNoteId = noteId
        #expect(vm.selectedNote?.id == noteId)
    }

    @Test func selectedNoteReturnsNilWhenNoneSelected() {
        let vm = makeViewModel()
        vm.selectedNoteId = nil
        #expect(vm.selectedNote == nil)
    }
}
