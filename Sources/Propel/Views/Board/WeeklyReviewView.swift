import SwiftUI

struct WeeklyReviewView: View {
    @Environment(BoardViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    private var data: WeeklyReviewData {
        viewModel.weeklyReviewData
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text("Weekly Review")
                    .font(.title3.bold())
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Stats summary
                    HStack(spacing: 16) {
                        StatCard(title: "Done", value: "\(data.completedCards.count)", color: .green, icon: "checkmark.circle.fill")
                        StatCard(title: "Active", value: "\(data.activeCards.count)", color: .blue, icon: "arrow.right.circle.fill")
                        StatCard(title: "Blocked", value: "\(data.blockedCards.count)", color: .orange, icon: "xmark.octagon.fill")
                        StatCard(title: "Overdue", value: "\(data.overdueCards.count)", color: .red, icon: "exclamationmark.circle.fill")
                    }

                    // Completed cards
                    if !data.completedCards.isEmpty {
                        ReviewSection(title: "Completed This Week", icon: "checkmark.circle.fill", color: .green) {
                            ForEach(data.completedCards) { card in
                                ReviewCardRow(card: card) {
                                    if let completedAt = card.completedAt {
                                        Text("Completed \(completedAt, style: .relative) ago")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    // Overdue cards
                    if !data.overdueCards.isEmpty {
                        ReviewSection(title: "Overdue", icon: "exclamationmark.triangle.fill", color: .red) {
                            ForEach(data.overdueCards) { card in
                                ReviewCardRow(card: card) {
                                    if let dueDate = card.dueDate {
                                        Text("Due \(dueDate, style: .relative) ago")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.red)
                                    }
                                }
                                .onTapGesture {
                                    viewModel.selectCard(card.id)
                                    dismiss()
                                }
                            }
                        }
                    }

                    if !data.blockedCards.isEmpty {
                        ReviewSection(title: "Blocked", icon: "xmark.octagon.fill", color: .orange) {
                            ForEach(data.blockedCards) { card in
                                ReviewCardRow(card: card) {
                                    Text("Blocked")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.orange)
                                }
                                .onTapGesture {
                                    viewModel.selectCard(card.id)
                                    dismiss()
                                }
                            }
                        }
                    }

                    if !data.activeCards.isEmpty {
                        ReviewSection(title: "Active", icon: "arrow.right.circle.fill", color: .blue) {
                            ForEach(data.activeCards) { card in
                                ReviewCardRow(card: card) {
                                    if let dueDate = card.dueDate {
                                        Text("Due \(dueDate, style: .date)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .onTapGesture {
                                    viewModel.selectCard(card.id)
                                    dismiss()
                                }
                            }
                        }
                    }

                    // Total
                    HStack {
                        Spacer()
                        Text("Total cards on board: \(data.totalCards)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 500, height: 500)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Review Section

private struct ReviewSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.bold())
            }
            content()
        }
    }
}

// MARK: - Review Card Row

private struct ReviewCardRow<Detail: View>: View {
    let card: Card
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(card.label.swiftUIColor)
                .frame(width: 6, height: 6)
            Text(card.title)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            detail()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
