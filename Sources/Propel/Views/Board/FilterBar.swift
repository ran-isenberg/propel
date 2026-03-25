import SwiftUI

struct FilterBar: View {
    @Environment(BoardViewModel.self) private var viewModel
    @State private var showWeeklyReview = false

    var body: some View {
        @Bindable var vm = viewModel
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundStyle(.secondary)
                .font(.caption)

            // Label filter
            Picker("Label", selection: $vm.filterLabel) {
                Text("All Labels").tag(Label?.none)
                Divider()
                ForEach(viewModel.sortedLabels) { label in
                    HStack {
                        Circle()
                            .fill(label.swiftUIColor)
                            .frame(width: 8, height: 8)
                        Text(label.rawValue)
                    }
                    .tag(Label?.some(label))
                }
            }
            .frame(width: 150)

            // Priority filter
            Picker("Priority", selection: $vm.filterPriority) {
                Text("All Priorities").tag(Priority?.none)
                Divider()
                ForEach(Priority.allCases) { priority in
                    Text(priority.displayName)
                        .tag(Priority?.some(priority))
                }
            }
            .frame(width: 160)

            if viewModel.isFilterActive {
                Button("Clear") {
                    viewModel.clearFilters()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .font(.caption)
            }

            Spacer()

            // Weekly Review button
            Button {
                showWeeklyReview = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption)
                    Text("Review")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Weekly Review")
            .sheet(isPresented: $showWeeklyReview) {
                WeeklyReviewView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
