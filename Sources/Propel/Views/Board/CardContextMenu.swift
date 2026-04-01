import SwiftUI

struct CardContextMenuModifier: ViewModifier {
    let card: Card
    let viewModel: BoardViewModel
    @State private var showDeleteConfirmation = false
    @State private var showDatePicker = false
    @State private var selectedDate = Date()

    func body(content: Content) -> some View {
        content
            .contextMenu {
                // Change Priority
                Menu("Change Priority") {
                    ForEach(Priority.allCases) { priority in
                        Button {
                            viewModel.changeCardPriority(card.id, to: priority)
                        } label: {
                            HStack {
                                Text(priority.displayName)
                                if card.priority == priority {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                // Change Label
                Menu("Change Label") {
                    ForEach(viewModel.board.sortedLabels) { labelDef in
                        Button {
                            viewModel.changeCardLabel(card.id, to: labelDef.id)
                        } label: {
                            HStack {
                                Text(labelDef.name)
                                if card.labelId == labelDef.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Divider()

                // Set Due Date
                Button("Set Due Date...") {
                    selectedDate = card.dueDate ?? Date()
                    showDatePicker = true
                }

                if card.dueDate != nil {
                    Button("Remove Due Date") {
                        viewModel.changeCardDueDate(card.id, to: nil)
                    }
                }

                Divider()

                // Block/Unblock
                if let blockedColumn = viewModel.column(for: .blocked) {
                    if card.columnId == blockedColumn.id {
                        Button("Unblock") {
                            viewModel.toggleCardBlocked(card.id)
                        }
                    } else {
                        Button("Mark as Blocked") {
                            viewModel.toggleCardBlocked(card.id)
                        }
                    }
                }

                Divider()

                // Duplicate
                Button("Duplicate") {
                    viewModel.duplicateCard(card.id)
                }

                Divider()

                // Delete
                Button("Delete", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
            .alert("Delete Card", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    viewModel.deleteCard(card.id)
                }
            } message: {
                Text("Delete \"\(card.title)\"? This action cannot be undone.")
            }
            .sheet(isPresented: $showDatePicker) {
                VStack(spacing: 16) {
                    Text("Set Due Date")
                        .font(.headline)
                    DatePicker("Due Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                    HStack {
                        Button("Cancel") {
                            showDatePicker = false
                        }
                        Spacer()
                        Button("Set Date") {
                            viewModel.changeCardDueDate(card.id, to: selectedDate)
                            showDatePicker = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(20)
                .frame(width: 300)
            }
    }
}

extension View {
    func cardContextMenu(card: Card, viewModel: BoardViewModel) -> some View {
        modifier(CardContextMenuModifier(card: card, viewModel: viewModel))
    }
}
