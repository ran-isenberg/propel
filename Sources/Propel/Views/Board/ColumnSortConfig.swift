import SwiftUI

struct ColumnSortConfig: View {
    let column: Column
    @Environment(BoardViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var primarySort: SortField
    @State private var secondarySort: SortField?

    init(column: Column) {
        self.column = column
        _primarySort = State(initialValue: column.sortBy.first ?? .priority)
        _secondarySort = State(initialValue: column.sortBy.count > 1 ? column.sortBy[1] : nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sort \(column.name)")
                .font(.headline)

            // Primary sort
            HStack {
                Text("Primary")
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                Picker("", selection: $primarySort) {
                    ForEach(SortField.allCases) { field in
                        Text(field.displayName).tag(field)
                    }
                }
                .labelsHidden()
            }

            // Secondary sort
            HStack {
                Text("Secondary")
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                Picker("", selection: $secondarySort) {
                    Text("None").tag(SortField?.none)
                    ForEach(SortField.allCases.filter { $0 != primarySort }) { field in
                        Text(field.displayName).tag(SortField?.some(field))
                    }
                }
                .labelsHidden()
            }

            HStack {
                Spacer()
                Button("Apply") {
                    var sortBy = [primarySort]
                    if let secondary = secondarySort {
                        sortBy.append(secondary)
                    }
                    viewModel.updateColumnSort(column.id, sortBy: sortBy)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 240)
    }
}
