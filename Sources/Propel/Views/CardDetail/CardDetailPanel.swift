import SwiftUI

struct CardDetailPanel: View {
    let cardId: UUID
    @Environment(BoardViewModel.self) private var viewModel
    @State private var showDeleteConfirmation = false

    private var card: Card? {
        viewModel.board.cards.first { $0.id == cardId }
    }

    var body: some View {
        Group {
            if let card {
                CardDetailContent(
                    card: card,
                    onUpdate: { viewModel.updateCard($0) },
                    onDelete: { showDeleteConfirmation = true },
                    columns: viewModel.sortedColumns,
                    onMoveToColumn: { viewModel.moveCard(cardId, toColumn: $0) }
                )
            } else {
                Text("Card not found")
                    .foregroundStyle(.secondary)
            }
        }
        .alert("Delete Card", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteCard(cardId)
            }
        } message: {
            Text("Delete this card? This action cannot be undone.")
        }
    }
}

private struct CardDetailContent: View {
    var card: Card
    let onUpdate: (Card) -> Void
    let onDelete: () -> Void
    let columns: [Column]
    let onMoveToColumn: (UUID) -> Void

    @State private var title: String
    @State private var description: String
    @State private var label: Label
    @State private var priority: Priority
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var checklist: [ChecklistItem]
    @State private var isRecurring: Bool
    @State private var recurrenceFrequency: Frequency
    @State private var recurrenceInterval: Int

    init(
        card: Card,
        onUpdate: @escaping (Card) -> Void,
        onDelete: @escaping () -> Void,
        columns: [Column],
        onMoveToColumn: @escaping (UUID) -> Void
    ) {
        self.card = card
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.columns = columns
        self.onMoveToColumn = onMoveToColumn
        _title = State(initialValue: card.title)
        _description = State(initialValue: card.description)
        _label = State(initialValue: card.label)
        _priority = State(initialValue: card.priority)
        _dueDate = State(initialValue: card.dueDate ?? Date())
        _hasDueDate = State(initialValue: card.dueDate != nil)
        _checklist = State(initialValue: card.checklist)
        _isRecurring = State(initialValue: card.isRecurring)
        _recurrenceFrequency = State(initialValue: card.recurrenceRule?.frequency ?? .weekly)
        _recurrenceInterval = State(initialValue: card.recurrenceRule?.interval ?? 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                TextField("Title", text: $title)
                    .font(.title2.bold())
                    .textFieldStyle(.plain)
                    .onChange(of: title) { saveChanges() }

                Divider()

                // Label
                HStack {
                    Text("Label")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Label", selection: $label) {
                        ForEach(Label.allCases) { l in
                            SwiftUI.Label {
                                Text(l.rawValue)
                            } icon: {
                                Circle()
                                    .fill(l.swiftUIColor)
                                    .frame(width: 8, height: 8)
                            }
                            .tag(l)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: label) { saveChanges() }
                }

                // Priority
                HStack {
                    Text("Priority")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: priority) { saveChanges() }
                }

                // Status
                HStack {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Status", selection: Binding(
                        get: { card.columnId },
                        set: { onMoveToColumn($0) }
                    )) {
                        ForEach(columns) { column in
                            Text(column.name).tag(column.id)
                        }
                    }
                    .labelsHidden()
                }

                // Due Date
                HStack {
                    Text("Due Date")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $hasDueDate)
                        .labelsHidden()
                        .onChange(of: hasDueDate) { saveChanges() }
                }
                if hasDueDate {
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: dueDate) { saveChanges() }
                }

                // Recurring
                HStack {
                    Text("Recurring")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $isRecurring)
                        .labelsHidden()
                        .onChange(of: isRecurring) {
                            if isRecurring, !hasDueDate {
                                hasDueDate = true
                            }
                            saveChanges()
                        }
                }
                if isRecurring {
                    HStack {
                        Text("Every")
                            .foregroundStyle(.secondary)
                        TextField("", value: $recurrenceInterval, format: .number)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: recurrenceInterval) { saveChanges() }
                        Picker("", selection: $recurrenceFrequency) {
                            ForEach(Frequency.allCases) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: recurrenceFrequency) { saveChanges() }
                    }
                }

                Divider()

                // Description
                Text("Description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $description)
                    .font(.body)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    )
                    .onChange(of: description) { saveChanges() }

                // Rich content: clickable links and video embeds
                RichDescriptionView(text: description)

                Divider()

                // Checklist
                ChecklistEditor(checklist: $checklist)
                    .onChange(of: checklist) { saveChanges() }

                Spacer()

                // Delete button
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Card")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
        }
    }

    private func saveChanges() {
        var updated = card
        updated.title = title
        updated.description = description
        updated.label = label
        updated.priority = priority
        updated.dueDate = hasDueDate ? dueDate : nil
        updated.checklist = checklist
        updated.isRecurring = isRecurring
        if isRecurring {
            updated.recurrenceRule = RecurrenceRule(interval: max(1, recurrenceInterval), frequency: recurrenceFrequency)
        } else {
            updated.recurrenceRule = nil
        }
        onUpdate(updated)
    }
}
