import SwiftUI

struct FilterBar: View {
    @Environment(BoardViewModel.self) private var viewModel
    @State private var showWeeklyReview = false
    @State private var showLabelManagement = false

    var body: some View {
        @Bindable var vm = viewModel
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundStyle(.secondary)
                .font(.caption)

            // Label filter
            Picker("Label", selection: $vm.filterLabel) {
                Text("All Labels").tag(UUID?.none)
                Divider()
                ForEach(viewModel.board.sortedLabels) { labelDef in
                    HStack {
                        Circle()
                            .fill(labelDef.swiftUIColor)
                            .frame(width: 8, height: 8)
                        Text(labelDef.name)
                    }
                    .tag(UUID?.some(labelDef.id))
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

            // Manage Labels button
            Button {
                showLabelManagement = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "tag.circle")
                    Text("Manage Labels")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Manage Labels")
            .sheet(isPresented: $showLabelManagement) {
                LabelManagementView()
                    .environment(viewModel)
            }

            // Weekly Review button
            Button {
                showWeeklyReview = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                    Text("Review")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
