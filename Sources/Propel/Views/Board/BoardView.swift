import SwiftUI

struct BoardView: View {
    @Environment(BoardViewModel.self) private var viewModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(viewModel.visibleStages) { stage in
                ColumnView(column: stage)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }
}
