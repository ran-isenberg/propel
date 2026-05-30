import SwiftUI

/// Quick switcher between the app's board positions (1...slotCount). Boards can be
/// reordered by dragging, renamed, or deleted. Cmd+1/2/3 switch positions.
struct BoardSwitcher: View {
    @Environment(BoardViewModel.self) private var boardViewModel

    @State private var renamePosition: Int?
    @State private var renameText = ""
    @State private var deletePosition: Int?
    @State private var dropTarget: Int?

    private var positions: [Int] { Array(1...BoardViewModel.slotCount) }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(positions, id: \.self) { position in
                slotButton(position)
            }
        }
        .alert("Rename Board", isPresented: renamePresented) {
            TextField("Board name", text: $renameText)
            Button("Cancel", role: .cancel) { renamePosition = nil }
            Button("Rename") {
                if let position = renamePosition, let id = boardId(at: position) {
                    Task { await boardViewModel.renameBoard(id: id, to: renameText) }
                }
                renamePosition = nil
            }
        }
        .alert("Delete Board", isPresented: deletePresented) {
            Button("Cancel", role: .cancel) { deletePosition = nil }
            Button("Delete", role: .destructive) {
                if let position = deletePosition {
                    Task { await boardViewModel.deleteBoard(atPosition: position) }
                }
                deletePosition = nil
            }
        } message: {
            if let position = deletePosition {
                Text("This resets board \(position) (\(name(for: position))) to an empty board. This cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private func slotButton(_ position: Int) -> some View {
        let isActive = boardViewModel.activeSlot == position
        let isDropTarget = dropTarget == position
        Button {
            Task { await boardViewModel.switchToPosition(position) }
        } label: {
            HStack(spacing: 5) {
                Text("\(position)")
                    .font(.caption.bold())
                    .foregroundStyle(isActive ? Color.white : Color.secondary)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle().fill(isActive ? Color.accentColor : Color.secondary.opacity(0.2))
                    )
                nameLabel(for: position, isActive: isActive)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor(isActive: isActive, isDropTarget: isDropTarget))
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\(position)")), modifiers: .command)
        .help("Switch to board \(position)")
        .draggable("\(position)")
        .dropDestination(for: String.self) { items, _ in
            guard let first = items.first, let from = Int(first), from != position else { return false }
            Task { await boardViewModel.swapPositions(from, position) }
            return true
        } isTargeted: { targeted in
            dropTarget = targeted ? position : (dropTarget == position ? nil : dropTarget)
        }
        .contextMenu {
            Button("Rename…") {
                renameText = boardViewModel.slotNames[position] ?? ""
                renamePosition = position
            }
            Divider()
            Button("Delete", role: .destructive) {
                deletePosition = position
            }
        }
    }

    @ViewBuilder
    private func nameLabel(for position: Int, isActive: Bool) -> some View {
        let raw = boardViewModel.slotNames[position] ?? ""
        if raw.isEmpty {
            Text("Untitled")
                .font(.callout)
                .italic()
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        } else {
            Text(raw)
                .font(.callout)
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
                .lineLimit(1)
        }
    }

    private func backgroundColor(isActive: Bool, isDropTarget: Bool) -> Color {
        if isDropTarget { return Color.accentColor.opacity(0.3) }
        if isActive { return Color.accentColor.opacity(0.15) }
        return Color.clear
    }

    private func name(for position: Int) -> String {
        let raw = boardViewModel.slotNames[position] ?? ""
        return raw.isEmpty ? "Untitled" : raw
    }

    private func boardId(at position: Int) -> UUID? {
        guard (1...boardViewModel.boardOrder.count).contains(position) else { return nil }
        return boardViewModel.boardOrder[position - 1]
    }

    private var renamePresented: Binding<Bool> {
        Binding(get: { renamePosition != nil }, set: { if !$0 { renamePosition = nil } })
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { deletePosition != nil }, set: { if !$0 { deletePosition = nil } })
    }
}
