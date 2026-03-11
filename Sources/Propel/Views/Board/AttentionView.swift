import SwiftUI

struct AttentionView: View {
    @Environment(BoardViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Needs Attention")
                    .font(.subheadline.bold())
                Text("(\(viewModel.attentionCards.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    viewModel.showAttentionView = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if viewModel.attentionCards.isEmpty {
                Text("All clear! No cards need attention.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.attentionCards) { card in
                            AttentionCardView(card: card)
                                .onTapGesture {
                                    viewModel.selectCard(card.id)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color.orange.opacity(0.05))
    }
}

struct AttentionCardView: View {
    let card: Card
    @Environment(BoardViewModel.self) private var viewModel

    private var isOverdue: Bool {
        guard let due = card.dueDate else { return false }
        return due < Date()
    }

    private var isDueSoon: Bool {
        guard let due = card.dueDate else { return false }
        let soonThreshold = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return due <= soonThreshold && due >= Date()
    }

    private var isBlocked: Bool {
        guard let blockedColumn = viewModel.column(for: .blocked) else { return false }
        return card.columnId == blockedColumn.id
    }

    private var statusColor: Color {
        if isOverdue { return .red }
        if isBlocked { return .red }
        if isDueSoon { return .orange }
        return .secondary
    }

    private var statusText: String {
        if isOverdue { return "Overdue" }
        if isBlocked { return "Blocked" }
        if isDueSoon { return "Due Soon" }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(statusColor)
                    .textCase(.uppercase)
            }

            Text(card.title)
                .font(.caption)
                .lineLimit(1)

            if let due = card.dueDate {
                Text(due, style: .date)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .frame(width: 140)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }
}
