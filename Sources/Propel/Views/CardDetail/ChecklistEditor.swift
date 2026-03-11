import SwiftUI

struct ChecklistEditor: View {
    @Binding var checklist: [ChecklistItem]
    @State private var newItemTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Checklist")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(Array(checklist.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 8) {
                    Button {
                        checklist[index].isCompleted.toggle()
                    } label: {
                        Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)

                    TextField("Item", text: Binding(
                        get: { checklist[index].title },
                        set: { checklist[index].title = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                    Button {
                        checklist.remove(at: index)
                        reindex()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(0.5)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)

                TextField("Add item...", text: $newItemTitle)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        addItem()
                    }
            }
            .padding(.top, 4)
        }
    }

    private static let maxChecklistItems = 100

    private func addItem() {
        let title = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, checklist.count < Self.maxChecklistItems else { return }
        let trimmedTitle = String(title.prefix(500))
        let item = ChecklistItem(title: trimmedTitle, position: checklist.count)
        checklist.append(item)
        newItemTitle = ""
    }

    private func reindex() {
        for i in checklist.indices {
            checklist[i].position = i
        }
    }
}
