import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            // App icon
            Image(systemName: "rectangle.split.3x1.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 8)

            // App name
            Text("Propel")
                .font(.title.bold())

            Text("Kanban-style task management for macOS")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            // Version info
            VStack(spacing: 4) {
                HStack {
                    Text("Version")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(AppInfo.version) (\(AppInfo.buildNumber))")
                }
                HStack {
                    Text("Built")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(AppInfo.buildDate)
                }
            }
            .font(.caption)
            .frame(width: 220)

            Divider()
                .frame(width: 200)

            // Author
            VStack(spacing: 6) {
                Text(AppInfo.copyright)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link(destination: AppInfo.websiteURL) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.caption)
                        Text("ranthebuilder.cloud")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }

            // License
            Text(AppInfo.license)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
        .padding(24)
        .frame(width: 300)
    }
}
