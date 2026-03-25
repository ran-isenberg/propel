import SwiftUI

struct BoardConfigurationView: View {
    private enum ConfigurationTab: String, CaseIterable, Identifiable {
        case stages = "Stages"
        case labels = "Labels"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ConfigurationTab = .stages

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Configuration", selection: $selectedTab) {
                    ForEach(ConfigurationTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)

            Divider()

            Group {
                switch selectedTab {
                case .stages:
                    StageEditorView()
                case .labels:
                    LabelEditorView()
                }
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

private struct LabelEditorView: View {
    @Environment(BoardViewModel.self) private var viewModel

    @State private var selectedLabelId: UUID?
    @State private var replacementLabelId: UUID?
    @State private var showDeletePrompt = false

    private var selectedLabel: Label? {
        guard let selectedLabelId else { return nil }
        return viewModel.sortedLabels.first(where: { $0.id == selectedLabelId })
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedLabelId) {
                ForEach(viewModel.sortedLabels) { label in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(label.swiftUIColor)
                            .frame(width: 10, height: 10)
                        Text(label.name)
                    }
                    .tag(label.id)
                }
            }
            .navigationTitle("Labels")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        selectedLabelId = viewModel.addLabel()
                    } label: {
                        Image(systemName: "plus")
                    }

                    Button(role: .destructive) {
                        replacementLabelId = viewModel.availableReplacementLabels(excluding: selectedLabelId ?? UUID()).first?.id
                        showDeletePrompt = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedLabel == nil || viewModel.board.labels.count == 1)
                }
            }
        } detail: {
            if let selectedLabel {
                Form {
                    TextField(
                        "Label Name",
                        text: binding(for: \.name, defaultValue: selectedLabel.name)
                    )

                    ColorSwatchSelector(
                        title: "Color",
                        selection: binding(for: \.color, defaultValue: selectedLabel.color)
                    )
                }
                .formStyle(.grouped)
                .padding()
            } else {
                ContentUnavailableView("Select a Label", systemImage: "tag")
            }
        }
        .onAppear {
            selectedLabelId = selectedLabelId ?? viewModel.sortedLabels.first?.id
        }
        .sheet(isPresented: $showDeletePrompt) {
            deleteSheet
        }
    }

    private var deleteSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delete Label")
                .font(.title3.bold())

            Text("Choose the label that should replace cards using the deleted label.")
                .foregroundStyle(.secondary)

            if let selectedLabelId {
                Picker("Replacement", selection: Binding(
                    get: { replacementLabelId ?? viewModel.availableReplacementLabels(excluding: selectedLabelId).first?.id ?? UUID() },
                    set: { replacementLabelId = $0 }
                )) {
                    ForEach(viewModel.availableReplacementLabels(excluding: selectedLabelId)) { label in
                        Text(label.name).tag(label.id)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    showDeletePrompt = false
                }

                Spacer()

                Button("Delete", role: .destructive) {
                    guard let selectedLabelId, let replacementLabelId else { return }
                    viewModel.deleteLabel(selectedLabelId, replacementLabelId: replacementLabelId)
                    self.selectedLabelId = replacementLabelId
                    showDeletePrompt = false
                }
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func binding<Value: Equatable>(
        for keyPath: WritableKeyPath<Label, Value>,
        defaultValue: Value
    ) -> Binding<Value> {
        Binding(
            get: { selectedLabel?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                guard var label = selectedLabel else { return }
                label[keyPath: keyPath] = newValue
                viewModel.updateLabel(label)
            }
        )
    }
}
