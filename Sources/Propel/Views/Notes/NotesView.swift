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
                                viewModel.selectedNoteId = note.id
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
}
