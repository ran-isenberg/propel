import SwiftUI

struct MenuBarView: View {
    @Environment(BoardViewModel.self) private var viewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.board.name)
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
            if viewModel.overdueCount > 0 || viewModel.deliveredReminderCount > 0 {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.deliveredReminderCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("\(viewModel.deliveredReminderCount) reminder\(viewModel.deliveredReminderCount == 1 ? "" : "s")")
                                .font(.caption)
                        }
                    }
                    if viewModel.overdueCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text("\(viewModel.overdueCount) overdue")
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            Divider()

            // Quick actions
            Button {
                activateMainWindow()
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
                if let backlog = viewModel.column(for: .backlog) {
                    viewModel.startCreatingCard(inColumn: backlog.id)
                }
                activateMainWindow()
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
        .task {
            await viewModel.refreshDeliveredNotificationCount()
        }
    }

    private func activateMainWindow() {
        dismiss()
        // Deminiaturize any minimized windows first
        for window in NSApp.windows where window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        // Bring the main window to front, or open a new one if none exist
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
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
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}
