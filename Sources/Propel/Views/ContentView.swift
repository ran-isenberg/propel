import SwiftUI

enum NavigationTab: String, CaseIterable {
    case board = "Board"
    case notes = "Notes"
}

struct ContentView: View {
    @Environment(BoardViewModel.self) private var boardViewModel
    @State private var activeTab: NavigationTab = .board
    @State private var isEditingBoardName = false
    @FocusState private var boardNameFocused: Bool

    var body: some View {
        @Bindable var vm = boardViewModel
        VStack(spacing: 0) {
            // Top bar
            HStack {
                if isEditingBoardName {
                    TextField("Board Name", text: $vm.board.name)
                        .font(.title3.bold())
                        .textFieldStyle(.plain)
                        .fixedSize()
                        .focused($boardNameFocused)
                        .onSubmit {
                            isEditingBoardName = false
                            boardViewModel.scheduleBoardSave()
                        }
                        .onChange(of: boardNameFocused) {
                            if !boardNameFocused {
                                isEditingBoardName = false
                                boardViewModel.scheduleBoardSave()
                            }
                        }
                } else {
                    Text(boardViewModel.board.name)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .onTapGesture {
                            isEditingBoardName = true
                            boardNameFocused = true
                        }
                }

                Spacer()

                // Search field (Cmd+F)
                if boardViewModel.isSearching {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        TextField("Search cards...", text: $vm.searchText)
                            .textFieldStyle(.plain)
                            .frame(width: 200)
                        Button {
                            boardViewModel.toggleSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }

                // Attention button
                if activeTab == .board {
                    Button {
                        boardViewModel.showAttentionView.toggle()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: boardViewModel.attentionCards.isEmpty
                                ? "checkmark.seal.fill"
                                : "exclamationmark.triangle.fill")
                                .font(.caption)
                            if !boardViewModel.attentionCards.isEmpty {
                                Text("\(boardViewModel.attentionCards.count)")
                                    .font(.caption2.bold())
                            }
                        }
                        .foregroundStyle(boardViewModel.attentionCards.isEmpty ? Color.green : Color.orange)
                    }
                    .buttonStyle(.plain)
                    .help(boardViewModel.attentionCards.isEmpty ? "All clear" : "Cards needing attention")
                }

                Picker("", selection: $activeTab) {
                    ForEach(NavigationTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content
            switch activeTab {
            case .board:
                FilterBar()
                Divider()

                if boardViewModel.showAttentionView {
                    AttentionView()
                    Divider()
                }

                HStack(spacing: 0) {
                    BoardView()
                        .frame(maxWidth: .infinity)

                    if boardViewModel.showSidePanel {
                        Divider()
                        sidePanelContent
                            .frame(width: 340)
                            .transition(.move(edge: .trailing))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: boardViewModel.showSidePanel)

            case .notes:
                NotesView()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    boardViewModel.toggleSearch()
                } label: {
                    SwiftUI.Label("Search", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    if activeTab == .board {
                        if let backlogColumn = boardViewModel.column(for: .backlog) {
                            boardViewModel.startCreatingCard(inColumn: backlogColumn.id)
                        }
                    }
                } label: {
                    SwiftUI.Label("New Card", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(activeTab != .board)
            }
        }
    }

    @ViewBuilder
    private var sidePanelContent: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button {
                    boardViewModel.closeSidePanel()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if boardViewModel.isCreatingCard, let columnId = boardViewModel.creationTargetColumnId {
                CardCreationPanel(initialColumnId: columnId)
            } else if let cardId = boardViewModel.selectedCardId {
                CardDetailPanel(cardId: cardId)
                    .id(cardId)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
