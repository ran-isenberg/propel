import SwiftUI

struct CardCreationPanel: View {
    let initialStageId: UUID
    @Environment(BoardViewModel.self) private var viewModel

    @State private var selectedStageId: UUID
    @State private var title = ""
    @State private var label: Label
    @State private var priority: Priority = .normal
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var showDatePicker = false
    @State private var hasTime = false
    @State private var reminder: ReminderOffset = .none
    @State private var isRecurring = false
    @State private var recurrenceFrequency: Frequency = .weekly
    @State private var recurrenceInterval: Int = 1

    private var availableStages: [Stage] {
        viewModel.sortedStages.filter(\.allowsManualCardCreation)
    }

    init(initialStageId: UUID) {
        self.initialStageId = initialStageId
        _selectedStageId = State(initialValue: initialStageId)
        _label = State(initialValue: .blogPost)
    }

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
                        .onChange(of: title) {
                            if title.count > 200 { title = String(title.prefix(200)) }
                        }
                }

                // Label (required)
                HStack {
                    Text("Label *")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Label", selection: $label) {
                        ForEach(viewModel.sortedLabels) { l in
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

                // Stage
                HStack {
                    Text("Stage *")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Stage", selection: $selectedStageId) {
                        ForEach(availableStages) { stage in
                            SwiftUI.Label {
                                Text(stage.name)
                            } icon: {
                                Image(systemName: stage.icon)
                                    .foregroundStyle(stage.color.swiftUIColor)
                            }
                            .tag(stage.id)
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
                        .onChange(of: description) {
                            if description.count > 10_000 { description = String(description.prefix(10_000)) }
                        }
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
                    HStack {
                        Button(dueDate.formatted(date: .abbreviated, time: .omitted)) {
                            showDatePicker.toggle()
                        }
                        .popover(isPresented: $showDatePicker) {
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .padding()
                                .onChange(of: dueDate) {
                                    showDatePicker = false
                                }
                        }
                        Spacer()
                        Toggle("Time", isOn: $hasTime)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if hasTime {
                        DatePicker("", selection: $dueDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }

                // Reminder
                if hasDueDate {
                    HStack {
                        Text("Reminder")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Reminder", selection: $reminder) {
                            ForEach(ReminderOffset.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .labelsHidden()
                    }
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
                        }
                }
                if isRecurring {
                    HStack {
                        Text("Every")
                            .foregroundStyle(.secondary)
                        TextField("", value: $recurrenceInterval, format: .number)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                        Picker("", selection: $recurrenceFrequency) {
                            ForEach(Frequency.allCases) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        .labelsHidden()
                    }
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
        .onAppear {
            if let firstLabel = viewModel.sortedLabels.first {
                label = firstLabel
            }
        }
    }

    private func createCard() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let recurrenceRule = isRecurring ? RecurrenceRule(interval: min(max(1, recurrenceInterval), 999), frequency: recurrenceFrequency) : nil
        viewModel.createCard(
            title: trimmedTitle,
            label: label,
            priority: priority,
            description: description,
            dueDate: hasDueDate ? dueDate : nil,
            isRecurring: isRecurring,
            recurrenceRule: recurrenceRule,
            reminder: hasDueDate ? reminder : .none,
            inStage: selectedStageId
        )
    }
}
