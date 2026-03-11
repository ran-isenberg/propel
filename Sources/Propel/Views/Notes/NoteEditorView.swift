import SwiftUI

struct NoteEditorView: View {
    let note: Note
    let onUpdate: (Note) -> Void

    @State private var title: String
    @State private var content: String

    init(note: Note, onUpdate: @escaping (Note) -> Void) {
        self.note = note
        self.onUpdate = onUpdate
        _title = State(initialValue: note.title)
        _content = State(initialValue: note.content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Note title", text: $title)
                .font(.title2.bold())
                .textFieldStyle(.plain)
                .onChange(of: title) { saveChanges() }

            Divider()

            TextEditor(text: $content)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .onChange(of: content) { saveChanges() }
        }
        .padding(16)
        .onChange(of: note.id) {
            title = note.title
            content = note.content
        }
    }

    private func saveChanges() {
        var updated = note
        updated.title = title
        updated.content = content
        onUpdate(updated)
    }
}
