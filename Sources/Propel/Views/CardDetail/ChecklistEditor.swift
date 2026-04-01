import SwiftUI

struct ChecklistEditor: View {
    @Binding var checklist: [ChecklistItem]
    @State private var newItemTitle = ""
    @State private var isAddingItem = false
    @State private var draggedItemId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Checklist")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !checklist.isEmpty {
                    Text("\(checklist.filter(\.isCompleted).count)/\(checklist.count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if !isAddingItem, checklist.isEmpty {
                    Button {
                        isAddingItem = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.caption)
                            Text("Add Item")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(Array(checklist.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12))
                        .foregroundStyle(.quaternary)
                        .frame(width: 20, height: 28)
                        .contentShape(Rectangle())

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
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(draggedItemId != nil ? Color.accentColor.opacity(0.0) : .clear)
                )
                .draggable(item.id.uuidString) {
                    // Drag preview — full row
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.isCompleted ? .green : .secondary)
                        Text(item.title)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .shadow(radius: 3)
                    )
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let draggedIdString = items.first,
                          let draggedId = UUID(uuidString: draggedIdString),
                          let fromIndex = checklist.firstIndex(where: { $0.id == draggedId }),
                          fromIndex != index
                    else { return false }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        let moved = checklist.remove(at: fromIndex)
                        checklist.insert(moved, at: index)
                        reindex()
                    }
                    return true
                } isTargeted: { targeted in
                    draggedItemId = targeted ? item.id : nil
                }
            }

            if !checklist.isEmpty || isAddingItem {
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
