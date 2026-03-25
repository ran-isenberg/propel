import SwiftUI

struct ColorSwatchSelector: View {
    let title: String
    @Binding var selection: StageColor

    private let columns = Array(repeating: GridItem(.flexible(minimum: 28, maximum: 40), spacing: 10), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 8) {
                    Circle()
                        .fill(selection.swiftUIColor)
                        .frame(width: 12, height: 12)
                    Text(selection.displayName)
                        .foregroundStyle(.primary)
                }
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(StageColor.allCases) { color in
                    Button {
                        selection = color
                    } label: {
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: 24, height: 24)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        selection == color ? Color.white.opacity(0.9) : Color.white.opacity(0.14),
                                        lineWidth: selection == color ? 3 : 1
                                    )
                            }
                            .shadow(color: color.swiftUIColor.opacity(selection == color ? 0.35 : 0), radius: 8)
                    }
                    .buttonStyle(.plain)
                    .help(color.displayName)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
