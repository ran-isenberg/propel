import SwiftUI

struct ColumnView: View {
    let column: Column
    @Environment(BoardViewModel.self) private var viewModel
    @State private var isTargeted = false
    @State private var showSortConfig = false
    @State private var showClearConfirmation = false
    @State private var celebrationId = UUID()
    @State private var showCelebration = false

    private var isCompletedColumn: Bool {
        column.status == .completed
    }

    private var isCollapsed: Bool {
        viewModel.isColumnCollapsed(column.id)
    }

    private var cards: [Card] {
        viewModel.cardsForColumn(column)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header — ClickUp style
            HStack(spacing: 8) {
                // Collapse toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.toggleColumnCollapsed(column.id)
                    }
                } label: {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                // Status pill badge
                HStack(spacing: 5) {
                    Image(systemName: column.status.headerIcon)
                        .font(.system(size: 11, weight: .bold))
                    Text(column.name.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(column.status.headerColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(column.status.headerColor.opacity(0.15))
                )
                .fixedSize()

                // Card count
                Text("\(cards.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if !isCollapsed {
                    // Sort button
                    Button {
                        showSortConfig = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Sort options")
                    .popover(isPresented: $showSortConfig) {
                        ColumnSortConfig(column: column)
                    }

                    if isCompletedColumn && !cards.isEmpty {
                        // Clear completed button
                        Button {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Clear all completed tasks")
                    }

                    if !isCompletedColumn {
                        // Add button
                        Button {
                            viewModel.startCreatingCard(inColumn: column.id)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Add card to \(column.name)")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if !isCollapsed {
                // Cards list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(cards) { card in
                            CardView(card: card)
                                .draggable(card.id.uuidString)
                                .cardContextMenu(card: card, viewModel: viewModel)
                        }

                        // "+ Add Task" button at bottom
                        if cards.isEmpty, !isCompletedColumn {
                            Button {
                                viewModel.startCreatingCard(inColumn: column.id)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14))
                                    Text("Add Task")
                                        .font(.system(size: 14))
                                }
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(minWidth: isCollapsed ? 50 : 160, maxWidth: isCollapsed ? 50 : .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isTargeted
                    ? Color.accentColor.opacity(0.08)
                    : Color(nsColor: .windowBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isTargeted
                        ? Color.accentColor.opacity(0.5)
                        : Color(nsColor: .separatorColor).opacity(0.15),
                    lineWidth: isTargeted ? 1.5 : 0.5
                )
        )
        .overlay {
            if showCelebration {
                CompletionCelebration()
                    .id(celebrationId)
            }
        }
        .alert("Clear Completed Tasks", isPresented: $showClearConfirmation) {
            Button("Clear All", role: .destructive) {
                withAnimation {
                    viewModel.clearCompletedCards()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(cards.count) completed tasks. This action cannot be undone.")
        }
        .dropDestination(for: String.self) { items, _ in
            guard let cardIdString = items.first,
                  let cardId = UUID(uuidString: cardIdString)
            else {
                return false
            }
            let isNewArrival = isCompletedColumn &&
                viewModel.board.cards.first(where: { $0.id == cardId })?.columnId != column.id

            viewModel.moveCard(cardId, toColumn: column.id)

            if isNewArrival {
                celebrationId = UUID()
                showCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    showCelebration = false
                }
            }
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}
