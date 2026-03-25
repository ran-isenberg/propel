import SwiftUI

struct StageEditorView: View {
    @Environment(BoardViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStageId: UUID?
    @State private var replacementStageId: UUID?
    @State private var showDeletePrompt = false

    private let iconOptions = [
        "tray.fill",
        "arrow.right.circle.fill",
        "checkmark.circle.fill",
        "shippingbox.fill",
        "doc.text.fill",
        "sparkles",
        "flag.checkered",
        "clock.fill",
        "pause.circle.fill",
        "folder.fill",
        "paperplane.fill",
        "list.bullet.rectangle.fill"
    ]

    private var selectedStage: Stage? {
        guard let selectedStageId else { return nil }
        return viewModel.stage(withId: selectedStageId)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedStageId) {
                ForEach(viewModel.sortedStages) { stage in
                    HStack(spacing: 8) {
                        Image(systemName: stage.icon)
                            .foregroundStyle(stage.color.swiftUIColor)
                        Text(stage.name)
                        if stage.isDefaultIntake {
                            Text("Default")
                                .font(.caption2.bold())
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue.opacity(0.12)))
                        }
                        if stage.isDoneStage {
                            Text("Done")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.12)))
                        }
                    }
                    .tag(stage.id)
                }
            }
            .navigationTitle("Stages")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        selectedStageId = viewModel.addStage()
                    } label: {
                        Image(systemName: "plus")
                    }

                    Button {
                        moveSelectedStage(offset: -1)
                    } label: {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(!canMoveSelectedStage(offset: -1))

                    Button {
                        moveSelectedStage(offset: 1)
                    } label: {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(!canMoveSelectedStage(offset: 1))

                    Button(role: .destructive) {
                        replacementStageId = viewModel.availableReplacementStages(excluding: selectedStageId ?? UUID()).first?.id
                        showDeletePrompt = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedStage == nil || viewModel.board.stages.count == 1)
                }
            }
        } detail: {
            if let selectedStage {
                Form {
                    TextField(
                        "Stage Name",
                        text: binding(for: \.name, defaultValue: selectedStage.name)
                    )

                    Picker("Icon", selection: binding(for: \.icon, defaultValue: selectedStage.icon)) {
                        ForEach(iconOptions, id: \.self) { icon in
                            SwiftUI.Label(icon, systemImage: icon).tag(icon)
                        }
                    }

                    Picker("Color", selection: binding(for: \.color, defaultValue: selectedStage.color)) {
                        ForEach(StageColor.allCases) { color in
                            SwiftUI.Label(color.displayName, systemImage: "circle.fill")
                                .foregroundStyle(color.swiftUIColor)
                                .tag(color)
                        }
                    }

                    Toggle(
                        "Done Stage",
                        isOn: binding(for: \.isDoneStage, defaultValue: selectedStage.isDoneStage)
                    )

                    Toggle(
                        "Default Intake Stage",
                        isOn: Binding(
                            get: { selectedStage.isDefaultIntake },
                            set: { isEnabled in
                                guard isEnabled else { return }
                                viewModel.setDefaultIntakeStage(selectedStage.id)
                            }
                        )
                    )
                    .disabled(selectedStage.isDoneStage)

                    Toggle(
                        "Allow Manual Card Creation",
                        isOn: binding(
                            for: \.allowsManualCardCreation,
                            defaultValue: selectedStage.allowsManualCardCreation
                        )
                    )
                    .disabled(selectedStage.isDoneStage)
                }
                .formStyle(.grouped)
                .padding()
            } else {
                ContentUnavailableView("Select a Stage", systemImage: "square.3.layers.3d")
            }
        }
        .frame(minWidth: 760, minHeight: 420)
        .onAppear {
            selectedStageId = selectedStageId ?? viewModel.sortedStages.first?.id
        }
        .sheet(isPresented: $showDeletePrompt) {
            deleteSheet
        }
    }

    private var deleteSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delete Stage")
                .font(.title3.bold())

            Text("Choose the stage that should receive cards from the deleted stage.")
                .foregroundStyle(.secondary)

            if let selectedStageId {
                Picker("Replacement", selection: Binding(
                    get: { replacementStageId ?? viewModel.availableReplacementStages(excluding: selectedStageId).first?.id ?? UUID() },
                    set: { replacementStageId = $0 }
                )) {
                    ForEach(viewModel.availableReplacementStages(excluding: selectedStageId)) { stage in
                        Text(stage.name).tag(stage.id)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    showDeletePrompt = false
                }

                Spacer()

                Button("Delete", role: .destructive) {
                    guard let selectedStageId, let replacementStageId else { return }
                    viewModel.deleteStage(selectedStageId, replacementStageId: replacementStageId)
                    self.selectedStageId = replacementStageId
                    showDeletePrompt = false
                }
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func binding<Value: Equatable>(
        for keyPath: WritableKeyPath<Stage, Value>,
        defaultValue: Value
    ) -> Binding<Value> {
        Binding(
            get: { selectedStage?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                guard var stage = selectedStage else { return }
                stage[keyPath: keyPath] = newValue
                viewModel.updateStage(stage)
            }
        )
    }

    private func canMoveSelectedStage(offset: Int) -> Bool {
        guard let selectedStageId,
              let index = viewModel.sortedStages.firstIndex(where: { $0.id == selectedStageId })
        else {
            return false
        }
        let target = index + offset
        return target >= 0 && target < viewModel.sortedStages.count
    }

    private func moveSelectedStage(offset: Int) {
        guard let selectedStageId,
              let index = viewModel.sortedStages.firstIndex(where: { $0.id == selectedStageId })
        else {
            return
        }
        let target = index + offset
        guard target >= 0, target < viewModel.sortedStages.count else { return }
        viewModel.moveStages(fromOffsets: IndexSet(integer: index), toOffset: offset > 0 ? target + 1 : target)
    }
}
