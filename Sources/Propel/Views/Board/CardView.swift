import SwiftUI

struct CardView: View {
    let card: Card
    @Environment(BoardViewModel.self) private var viewModel

    private var isSelected: Bool {
        card.id == viewModel.selectedCardId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text(card.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
                .foregroundStyle(.primary)
                .padding(.bottom, 2)

            // Subtitle: column name
            if let col = viewModel.board.columns.first(where: { $0.id == card.columnId }) {
                Text("In \(col.name)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)
            }

            // Checklist row
            if !card.checklist.isEmpty {
                CardPropertyRow(icon: "checklist") {
                    ChecklistProgressView(checklist: card.checklist)
                }
            }

            // Due date row
            CardPropertyRow(icon: "calendar") {
                if let dueDate = card.dueDate {
                    let isOverdue = dueDate < Date()
                    Text(dueDate, style: .date)
                        .font(.system(size: 11))
                        .foregroundStyle(isOverdue ? .red : .secondary)
                } else {
                    Text("-")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            // Priority row
            CardPropertyRow(icon: "flag.fill") {
                PriorityBadge(priority: card.priority)
            }

            // Labels row
            CardPropertyRow(icon: "tag") {
                LabelBadge(label: card.label)
            }

            // Recurring indicator
            if card.isRecurring {
                CardPropertyRow(icon: "arrow.triangle.2.circlepath") {
                    Text("Recurring")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected
                        ? Color.accentColor
                        : Color(nsColor: .separatorColor).opacity(0.3),
                    lineWidth: isSelected ? 2 : 0.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectCard(card.id)
        }
    }
}

// MARK: - Card Property Row

struct CardPropertyRow<Content: View>: View {
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 14, alignment: .center)
            content()
            Spacer()
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Label Badge

struct LabelBadge: View {
    let label: Label

    var body: some View {
        Text(label.rawValue)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(label.swiftUIColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(label.swiftUIColor.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(label.swiftUIColor.opacity(0.3), lineWidth: 0.5)
            )
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.fill")
                .font(.system(size: 9))
            Text(priority.displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        switch priority {
        case .urgent: .red
        case .normal: .orange
        case .low: .gray
        }
    }
}

// MARK: - Checklist Progress

struct ChecklistProgressView: View {
    let checklist: [ChecklistItem]

    private var completed: Int {
        checklist.filter(\.isCompleted).count
    }

    private var progress: Double {
        Double(completed) / Double(checklist.count)
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    var body: some View {
        HStack(spacing: 6) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: .infinity)
                .tint(progress == 1.0 ? .green : .accentColor)

            Text("\(percentage)%")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}
