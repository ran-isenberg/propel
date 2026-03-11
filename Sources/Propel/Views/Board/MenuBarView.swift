import SwiftUI

struct MenuBarView: View {
    @Environment(BoardViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ran's Board")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            Divider()

            // Quick stats
            HStack(spacing: 16) {
                MenuBarStat(
                    icon: "tray",
                    label: "Backlog",
                    count: cardCount(for: .backlog),
                    color: .secondary
                )
                MenuBarStat(
                    icon: "arrow.right.circle",
                    label: "In Progress",
                    count: cardCount(for: .inProgress),
                    color: .blue
                )
                MenuBarStat(
                    icon: "xmark.octagon",
                    label: "Blocked",
                    count: cardCount(for: .blocked),
                    color: .red
                )
                MenuBarStat(
                    icon: "checkmark.circle",
                    label: "Done",
                    count: cardCount(for: .completed),
                    color: .green
                )
            }
            .padding(.horizontal, 12)

            // Attention items
            if viewModel.overdueCount > 0 || viewModel.blockedCount > 0 {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.overdueCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text("\(viewModel.overdueCount) overdue")
                                .font(.caption)
                        }
                    }
                    if viewModel.blockedCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text("\(viewModel.blockedCount) blocked")
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            Divider()

            // Quick actions
            Button {
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Open Board")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            Button {
                NSApp.activate(ignoringOtherApps: true)
                if let backlog = viewModel.column(for: .backlog) {
                    viewModel.startCreatingCard(inColumn: backlog.id)
                }
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Quick Add Card")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: 280)
    }

    private func cardCount(for status: ColumnStatus) -> Int {
        guard let column = viewModel.column(for: status) else { return 0 }
        return viewModel.board.cards.count(where: { $0.columnId == column.id })
    }
}

private struct MenuBarStat: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.caption.bold())
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
