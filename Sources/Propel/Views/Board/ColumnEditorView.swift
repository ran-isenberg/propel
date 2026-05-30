import SwiftUI

/// Editor for a board's columns: rename, recolor, change icon, reorder, add, and
/// delete. The intake, blocked, and done columns carry special workflow roles
/// and cannot be deleted, though they can still be renamed, recolored, and moved.
struct ColumnEditorView: View {
    @Environment(BoardViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedColumnId: UUID?
    @State private var replacementColumnId: UUID?
    @State private var showDeletePrompt = false

    private let iconOptions = [
        "tray.fill",
        "arrow.right.circle.fill",
        "xmark.octagon.fill",
        "shippingbox.fill",
        "checkmark.circle.fill",
        "circle.dotted",
        "doc.text.fill",
        "sparkles",
        "flag.checkered",
        "clock.fill",
        "pause.circle.fill",
        "folder.fill",
        "paperplane.fill",
        "list.bullet.rectangle.fill"
    ]

    private var selectedColumn: Column? {
        guard let selectedColumnId else { return nil }
        return viewModel.board.columns.first { $0.id == selectedColumnId }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedColumnId) {
                ForEach(viewModel.sortedColumns) { column in
                    HStack(spacing: 8) {
                        Image(systemName: column.icon)
                            .foregroundStyle(column.color.swiftUIColor)
                        Text(column.name)
                        Spacer()
                        roleBadge(for: column)
                    }
                    .tag(column.id)
                }
            }
            .navigationTitle("Columns")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        selectedColumnId = viewModel.addColumn()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add column")

                    Button {
                        moveSelectedColumn(offset: -1)
                    } label: {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(!canMoveSelectedColumn(offset: -1))

                    Button {
                        moveSelectedColumn(offset: 1)
                    } label: {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(!canMoveSelectedColumn(offset: 1))

                    Button(role: .destructive) {
                        guard let selectedColumnId else { return }
                        replacementColumnId = viewModel.availableReplacementColumns(excluding: selectedColumnId).first?.id
                        showDeletePrompt = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedColumnId == nil || !(selectedColumnId.map(viewModel.canDeleteColumn) ?? false))
                    .help("Delete column")
                }
            }
        } detail: {
            if let selectedColumn {
                Form {
                    TextField(
                        "Column Name",
                        text: binding(for: \.name, defaultValue: selectedColumn.name)
                    )

                    Picker("Icon", selection: binding(for: \.icon, defaultValue: selectedColumn.icon)) {
                        ForEach(iconOptions, id: \.self) { icon in
                            SwiftUI.Label(icon, systemImage: icon).tag(icon)
                        }
                    }

                    LabeledContent("Color") {
                        StageColorSwatchPicker(
                            selection: binding(for: \.color, defaultValue: selectedColumn.color)
                        )
                    }

                    if selectedColumn.isProtected {
                        Section {
                            Text(protectedNote(for: selectedColumn))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .formStyle(.grouped)
                .padding()
            } else {
                ContentUnavailableView("Select a Column", systemImage: "square.3.layers.3d")
            }
        }
        .frame(minWidth: 720, minHeight: 420)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .onAppear {
            selectedColumnId = selectedColumnId ?? viewModel.sortedColumns.first?.id
        }
        .sheet(isPresented: $showDeletePrompt) {
            deleteSheet
        }
    }

    @ViewBuilder
    private func roleBadge(for column: Column) -> some View {
        if column.isDefaultIntake {
            badge("Intake", color: .blue)
        } else if column.isBlockedStage {
            badge("Blocked", color: .red)
        } else if column.isDoneStage {
            badge("Done", color: .green)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func protectedNote(for column: Column) -> String {
        if column.isDefaultIntake {
            "New and recurring cards land here. This column can't be deleted."
        } else if column.isBlockedStage {
            "Blocked cards surface in the attention list. This column can't be deleted."
        } else {
            "Cards moved here are marked complete. This column can't be deleted."
        }
    }

    private var deleteSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delete Column")
                .font(.title3.bold())

            Text("Choose the column that should receive cards from the deleted column.")
                .foregroundStyle(.secondary)

            if let selectedColumnId {
                Picker("Move cards to", selection: Binding(
                    get: { replacementColumnId ?? viewModel.availableReplacementColumns(excluding: selectedColumnId).first?.id ?? UUID() },
                    set: { replacementColumnId = $0 }
                )) {
                    ForEach(viewModel.availableReplacementColumns(excluding: selectedColumnId)) { column in
                        Text(column.name).tag(column.id)
                    }
                }
            }

            HStack {
                Button("Cancel") { showDeletePrompt = false }
                Spacer()
                Button("Delete", role: .destructive) {
                    guard let selectedColumnId, let replacementColumnId else { return }
                    viewModel.deleteColumn(selectedColumnId, replacementColumnId: replacementColumnId)
                    self.selectedColumnId = replacementColumnId
                    showDeletePrompt = false
                }
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func binding<Value: Equatable>(
        for keyPath: WritableKeyPath<Column, Value>,
        defaultValue: Value
    ) -> Binding<Value> {
        Binding(
            get: { selectedColumn?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                guard var column = selectedColumn else { return }
                column[keyPath: keyPath] = newValue
                viewModel.updateColumn(column)
            }
        )
    }

    private func canMoveSelectedColumn(offset: Int) -> Bool {
        guard let selectedColumnId,
              let index = viewModel.sortedColumns.firstIndex(where: { $0.id == selectedColumnId })
        else { return false }
        let target = index + offset
        return target >= 0 && target < viewModel.sortedColumns.count
    }

    private func moveSelectedColumn(offset: Int) {
        guard let selectedColumnId,
              let index = viewModel.sortedColumns.firstIndex(where: { $0.id == selectedColumnId })
        else { return }
        let target = index + offset
        guard target >= 0, target < viewModel.sortedColumns.count else { return }
        viewModel.moveColumns(fromOffsets: IndexSet(integer: index), toOffset: offset > 0 ? target + 1 : target)
    }
}

// MARK: - Color Swatch Picker

/// A row of tappable color swatches. Used instead of a menu `Picker` because
/// SwiftUI menu pickers on macOS render their items in the default style and
/// drop the per-item color, making every choice look gray.
private struct StageColorSwatchPicker: View {
    @Binding var selection: StageColor

    private let columns = [GridItem(.adaptive(minimum: 26), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .trailing, spacing: 8) {
            ForEach(StageColor.allCases) { color in
                Button {
                    selection = color
                } label: {
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2)
                                .padding(-2)
                                .opacity(selection == color ? 1 : 0)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(color.displayName)
            }
        }
    }
}
