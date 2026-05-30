import SwiftUI

struct MenuBarView: View {
    @Environment(BoardViewModel.self) private var viewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All Boards")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            Divider()

            // Quick stats, grouped by workflow role across all boards.
            HStack(spacing: 16) {
                MenuBarStat(
                    icon: "tray",
                    label: "Backlog",
                    count: viewModel.aggregateRoleCounts.intake,
                    color: .secondary
                )
                MenuBarStat(
                    icon: "arrow.right.circle",
                    label: "Active",
                    count: viewModel.aggregateRoleCounts.active,
                    color: .blue
                )
                MenuBarStat(
                    icon: "xmark.octagon",
                    label: "Blocked",
                    count: viewModel.aggregateRoleCounts.blocked,
                    color: .red
                )
                MenuBarStat(
                    icon: "checkmark.circle",
                    label: "Done",
                    count: viewModel.aggregateRoleCounts.done,
                    color: .green
                )
            }
            .padding(.horizontal, 12)

            // Attention items
            if viewModel.aggregateOverdueCount > 0 || viewModel.deliveredReminderCount > 0 {
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
                    if viewModel.aggregateOverdueCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text("\(viewModel.aggregateOverdueCount) overdue")
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            Divider()

            // Quick actions
            MenuActionButton(icon: "macwindow", title: "Open Board") {
                activateMainWindow()
            }

            MenuActionButton(icon: "plus", title: "Quick Add Card") {
                if let intake = viewModel.intakeColumn {
                    viewModel.startCreatingCard(inColumn: intake.id)
                }
                activateMainWindow()
            }

            Divider()

            MenuActionButton(icon: "power", title: "Quit Propel", role: .destructive) {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding(.bottom, 8)
        }
        .frame(width: 280)
        .task {
            await viewModel.refreshDeliveredNotificationCount()
            await viewModel.refreshBoardsSummary()
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
}

/// A full-width menu row that highlights under the pointer so it's clear what's
/// about to be clicked.
private struct MenuActionButton: View {
    let icon: String
    let title: String
    var role: ButtonRole?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(role: role, action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovering ? Color.accentColor.opacity(0.18) : Color.clear)
                    .padding(.horizontal, 6)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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
