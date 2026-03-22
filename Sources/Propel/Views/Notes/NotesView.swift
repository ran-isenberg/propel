import SwiftUI

struct NotesView: View {
    @Environment(NotesViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel
        HSplitView {
            // Left: Notes list
            VStack(spacing: 0) {
                // Search
                TextField("Search notes...", text: $vm.searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(10)

                Divider()

                // Notes list
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.filteredNotes) { note in
                            NoteListItem(
                                note: note,
                                isSelected: note.id == viewModel.selectedNoteId
                            )
                            .onTapGesture {
                                flushAndSelect(note.id)
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    viewModel.confirmDeleteNote(note.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }

                Divider()

                // New note button
                Button {
                    flushCurrentEditor()
                    viewModel.createNote()
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("New Note")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(10)
            }
            .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

            // Right: Note editor
            Group {
                if let note = viewModel.selectedNote {
                    NoteEditorView(note: note) { updated in
                        viewModel.updateNote(updated)
                    }
                    .id(note.id)
                } else {
                    VStack {
                        Spacer()
                        Text("Select a note or create a new one")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onChange(of: vm.searchText) { _, _ in
            flushCurrentEditor()
        }
        .alert("Delete Note", isPresented: $vm.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.noteToDelete = nil
            }
            Button("Delete", role: .destructive) {
                viewModel.deleteNote()
            }
        } message: {
            Text("Delete this note? This action cannot be undone.")
        }
    }

    /// Flush any pending NSTextView edits into the view model before switching notes.
    private func flushCurrentEditor() {
        guard let currentId = viewModel.selectedNoteId,
              var currentNote = viewModel.store.notes.first(where: { $0.id == currentId }),
              let textView = NSApp.keyWindow?.firstResponder as? NSTextView
        else { return }

        let attributed = textView.attributedString()
        currentNote.content = attributed.string
        currentNote.rtfData = try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        viewModel.updateNote(currentNote)
    }

    private func flushAndSelect(_ noteId: UUID) {
        flushCurrentEditor()
        viewModel.selectedNoteId = noteId
    }
}
