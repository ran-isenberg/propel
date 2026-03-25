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
                .font(.system(size: 15, weight: .medium))
                .lineLimit(2)
                .foregroundStyle(.primary)
                .padding(.bottom, 2)

            // Subtitle: stage name
            if let stage = viewModel.board.stages.first(where: { $0.id == card.stageId }) {
                HStack(spacing: 6) {
                    Text("In \(stage.name)")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    if card.isBlocked {
                        Text("Blocked")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.15))
                            )
                    }
                }
                .padding(.bottom, 8)
            }

            HStack(spacing: 10) {
                DueDateBadge(dueDate: card.dueDate)
                PriorityBadge(priority: card.priority)
                LabelBadge(label: card.label)

                if card.isRecurring {
                    RecurringBadge()
                }
            }
            .padding(.bottom, card.checklist.isEmpty ? 0 : 8)

            if !card.checklist.isEmpty {
                ChecklistRow(checklist: card.checklist)
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
                        : Color.gray.opacity(0.4),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectCard(card.id)
        }
    }
}

// MARK: - Label Badge

struct LabelBadge: View {
    let label: Label

    var body: some View {
        Text(label.rawValue)
            .font(.system(size: 12, weight: .semibold))
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
            .lineLimit(1)
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.fill")
                .font(.system(size: 11))
            Text(priority.displayName)
                .font(.system(size: 13, weight: .medium))
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

// MARK: - Due Date Badge

struct DueDateBadge: View {
    let dueDate: Date?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 11))
            if let dueDate {
                Text(dueDate, style: .date)
                    .font(.system(size: 12, weight: .medium))
            } else {
                Text("-")
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        guard let dueDate else { return .gray }
        return dueDate < Date() ? .red : .secondary
    }
}

// MARK: - Recurring Badge

struct RecurringBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11))
            Text("Recurring")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Checklist Row

struct ChecklistRow: View {
    let checklist: [ChecklistItem]

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .frame(width: 14, alignment: .center)
            ChecklistProgressView(checklist: checklist)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Checklist Progress

struct ChecklistProgressView: View {
    let checklist: [ChecklistItem]

    private var completed: Int {
        checklist.filter(\.isCompleted).count
    }

    private var progress: Double {
        checklist.isEmpty ? 0 : Double(completed) / Double(checklist.count)
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
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}
