import AppKit
import Foundation
@testable import Propel
import Testing

// MARK: - Note Selection Switching Tests

@MainActor
struct NoteSelectionTests {
    private func makeViewModel() -> NotesViewModel {
        let vm = NotesViewModel()
        vm.store = NotesStore()
        return vm
    }

    @Test func switchingSelectionUpdatesSelectedNote() {
        let vm = makeViewModel()
        vm.createNote()
        vm.createNote()
        let firstId = vm.store.notes[0].id
        let secondId = vm.store.notes[1].id

        vm.selectedNoteId = firstId
        #expect(vm.selectedNote?.id == firstId)

        vm.selectedNoteId = secondId
        #expect(vm.selectedNote?.id == secondId)
    }

    @Test func updateThenSwitchPreservesContent() {
        let vm = makeViewModel()
        vm.createNote()
        vm.createNote()
        let firstId = vm.store.notes[0].id
        let secondId = vm.store.notes[1].id

        // Edit the first note
        vm.selectedNoteId = firstId
        guard var note1 = vm.store.notes.first(where: { $0.id == firstId }) else {
            Issue.record("First note not found")
            return
        }
        note1.title = "Edited Title"
        note1.content = "Edited content"
        vm.updateNote(note1)

        // Switch to the second note
        vm.selectedNoteId = secondId
        #expect(vm.selectedNote?.id == secondId)

        // Switch back — first note should retain edits
        vm.selectedNoteId = firstId
        let retrieved = vm.selectedNote
        #expect(retrieved?.title == "Edited Title")
        #expect(retrieved?.content == "Edited content")
    }

    @Test func updateNotePreservesRtfData() {
        let vm = makeViewModel()
        vm.createNote()
        let noteId = vm.store.notes[0].id

        let attributed = NSAttributedString(
            string: "Rich text",
            attributes: [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.white]
        )
        let rtfData = try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )

        var note = vm.store.notes[0]
        note.title = "Rich Note"
        note.content = "Rich text"
        note.rtfData = rtfData
        vm.updateNote(note)

        // Switch away and back
        vm.createNote()
        vm.selectedNoteId = vm.store.notes[1].id
        vm.selectedNoteId = noteId

        let retrieved = vm.store.notes.first { $0.id == noteId }
        #expect(retrieved?.rtfData == rtfData)
        #expect(retrieved?.content == "Rich text")
    }

    @Test func rapidNoteUpdatesAllPersistInStore() {
        let vm = makeViewModel()
        vm.createNote()
        vm.createNote()
        vm.createNote()

        // Simulate rapid edits across notes (like typing then quickly switching)
        for i in 0..<vm.store.notes.count {
            var note = vm.store.notes[i]
            note.title = "Note \(i)"
            note.content = "Content for note \(i)"
            vm.updateNote(note)
        }

        // Verify all updates stuck
        for i in 0..<vm.store.notes.count {
            let note = vm.store.notes[i]
            #expect(note.title == "Note \(i)")
            #expect(note.content == "Content for note \(i)")
        }
    }

    @Test func updateNoteTimestampAdvances() {
        let vm = makeViewModel()
        vm.createNote()
        let originalDate = vm.store.notes[0].updatedAt

        var note = vm.store.notes[0]
        note.title = "Updated"
        vm.updateNote(note)

        #expect(vm.store.notes[0].updatedAt >= originalDate)
    }

    @Test func deletingSelectedNoteThenSwitchingWorks() {
        let vm = makeViewModel()
        vm.createNote()
        vm.createNote()
        let firstId = vm.store.notes[0].id
        let secondId = vm.store.notes[1].id

        vm.selectedNoteId = firstId
        vm.confirmDeleteNote(firstId)
        vm.deleteNote()

        #expect(vm.selectedNoteId == nil)
        #expect(vm.selectedNote == nil)

        // Select remaining note — should work fine
        vm.selectedNoteId = secondId
        #expect(vm.selectedNote?.id == secondId)
    }

    @Test func createNoteWhileEditingSwitchesSelection() {
        let vm = makeViewModel()
        vm.createNote()
        let firstId = vm.store.notes[0].id

        var note = vm.store.notes[0]
        note.title = "In Progress Edit"
        vm.updateNote(note)

        // Creating a new note should switch selection to it
        vm.createNote()
        let newId = vm.selectedNoteId
        #expect(newId != firstId)
        #expect(vm.store.notes.count == 2)

        // Original note should still have its edits
        let original = vm.store.notes.first { $0.id == firstId }
        #expect(original?.title == "In Progress Edit")
    }
}
