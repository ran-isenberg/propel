import SwiftUI

struct CardCreationPanel: View {
    let targetColumnId: UUID
    @Environment(BoardViewModel.self) private var viewModel

    @State private var title = ""
    @State private var label: Label = .blogPost
    @State private var priority: Priority = .normal
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var hasDueDate = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("New Card")
                    .font(.title2.bold())

                Divider()

                // Title (required)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title *")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Card title", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                // Label (required)
                HStack {
                    Text("Label *")
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
                }

                // Priority (required)
                HStack {
                    Text("Priority *")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .labelsHidden()
                }

                Divider()

                // Description (optional)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $description)
                        .font(.body)
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                        )
                }

                // Due Date (optional)
                HStack {
                    Text("Due Date")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $hasDueDate)
                        .labelsHidden()
                }
                if hasDueDate {
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                }

                Spacer()

                // Action buttons
                HStack {
                    Button("Cancel") {
                        viewModel.closeSidePanel()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Create") {
                        createCard()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(16)
        }
    }

    private func createCard() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        viewModel.createCard(
            title: trimmedTitle,
            label: label,
            priority: priority,
            description: description,
            dueDate: hasDueDate ? dueDate : nil,
            inColumn: targetColumnId
        )
    }
}
