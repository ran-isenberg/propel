import SwiftUI

struct LabelManagementView: View {
    @Environment(BoardViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""
    @State private var newColorName = "blue"
    @State private var editingLabelId: UUID?
    @State private var editName = ""
    @State private var editColorName = ""
    @State private var showDeleteConfirmation = false
    @State private var showCannotDeleteAlert = false
    @State private var labelToDelete: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Manage Labels")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.board.sortedLabels) { labelDef in
                        if editingLabelId == labelDef.id {
                            editRow(for: labelDef)
                        } else {
                            labelRow(for: labelDef)
                        }
                    }
                }
            }

            Divider()

            // Add new label
            VStack(alignment: .leading, spacing: 8) {
                Text("New Label")
                    .font(.subheadline.bold())

                HStack(spacing: 8) {
                    TextField("Label name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)

                    ColorPaletteSelector(selectedColorName: $newColorName)

                    Button("Add") {
                        addLabel()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicateName(newName))
                }
            }
        }
        .padding(20)
        .frame(width: 500, height: 450)
        .alert("Delete Label", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { labelToDelete = nil }
            Button("Delete", role: .destructive) {
                if let id = labelToDelete {
                    viewModel.deleteLabel(id)
                    labelToDelete = nil
                }
            }
        } message: {
            if let id = labelToDelete, let labelDef = viewModel.board.labels.first(where: { $0.id == id }) {
                Text("Delete \"\(labelDef.name)\"?")
            }
        }
        .alert("Cannot Delete Label", isPresented: $showCannotDeleteAlert) {
            Button("OK") { labelToDelete = nil }
        } message: {
            if let id = labelToDelete, let labelDef = viewModel.board.labels.first(where: { $0.id == id }) {
                let count = viewModel.cardsUsingLabel(id)
                let suffix = count == 1 ? "" : "s"
                Text("\"\(labelDef.name)\" has \(count) card\(suffix) assigned. " +
                    "Remove or reassign the cards before deleting this label.")
            }
        }
    }

    private func labelRow(for labelDef: LabelDefinition) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(labelDef.swiftUIColor)
                .frame(width: 12, height: 12)

            Text(labelDef.name)
                .frame(maxWidth: .infinity, alignment: .leading)

            let count = viewModel.board.cards.count(where: { $0.labelId == labelDef.id })
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary))
            }

            Button {
                editingLabelId = labelDef.id
                editName = labelDef.name
                editColorName = labelDef.colorName
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Edit")

            Button {
                labelToDelete = labelDef.id
                if viewModel.canDeleteLabel(labelDef.id) {
                    showDeleteConfirmation = true
                } else {
                    showCannotDeleteAlert = true
                }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Delete")
            .disabled(viewModel.board.labels.count <= 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
    }

    private func editRow(for labelDef: LabelDefinition) -> some View {
        HStack(spacing: 8) {
            TextField("Name", text: $editName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)

            ColorPaletteSelector(selectedColorName: $editColorName)

            Button("Save") {
                viewModel.updateLabel(labelDef.id, name: editName.trimmingCharacters(in: .whitespacesAndNewlines), colorName: editColorName)
                editingLabelId = nil
            }
            .buttonStyle(.borderedProminent)
            .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicateName(editName, excluding: labelDef.id))

            Button("Cancel") {
                editingLabelId = nil
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.1)))
    }

    private func addLabel() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isDuplicateName(trimmed) else { return }
        viewModel.addLabel(name: trimmed, colorName: newColorName)
        newName = ""
    }

    private func isDuplicateName(_ name: String, excluding labelId: UUID? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return viewModel.board.labels.contains {
            $0.id != labelId && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
    }
}

// MARK: - Color Palette Selector

struct ColorPaletteSelector: View {
    @Binding var selectedColorName: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LabelColor.palette) { labelColor in
                Circle()
                    .fill(labelColor.color)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: selectedColorName == labelColor.name ? 2 : 0)
                    )
                    .overlay(
                        selectedColorName == labelColor.name
                            ? Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                            : nil
                    )
                    .onTapGesture {
                        selectedColorName = labelColor.name
                    }
            }
        }
    }
}

// MARK: - Inline Label Creator (for pickers)

struct InlineLabelCreator: View {
    @Environment(BoardViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var onCreated: ((UUID) -> Void)?

    @State private var name = ""
    @State private var colorName = "blue"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Label")
                .font(.headline)

            TextField("Label name", text: $name)
                .textFieldStyle(.roundedBorder)

            ColorPaletteSelector(selectedColorName: $colorName)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Add") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let newLabel = LabelDefinition(name: trimmed, colorName: colorName)
                    viewModel.board.labels.append(newLabel)
                    viewModel.scheduleBoardSave()
                    onCreated?(newLabel.id)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
