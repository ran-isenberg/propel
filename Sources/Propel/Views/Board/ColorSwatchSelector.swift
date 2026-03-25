import SwiftUI

struct ColorSwatchSelector: View {
    let title: String
    @Binding var selection: StageColor

    private let swatchSize: CGFloat = 24

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

            HStack(spacing: 10) {
                ForEach(StageColor.allCases) { color in
                    Button {
                        selection = color
                    } label: {
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: swatchSize, height: swatchSize)
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
