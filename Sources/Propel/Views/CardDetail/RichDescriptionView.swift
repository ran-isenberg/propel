import SwiftUI

/// Displays the card description with clickable links and embedded video previews.
struct RichDescriptionView: View {
    let text: String

    private var videoURLs: [URL] {
        extractVideoURLs(from: text)
    }

    private var linkURLs: [(String, URL)] {
        extractLinks(from: text)
    }

    var body: some View {
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Video embeds
                ForEach(Array(videoURLs.enumerated()), id: \.offset) { _, url in
                    VideoEmbedView(url: url)
                }

                // Detected links
                if !linkURLs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(linkURLs.enumerated()), id: \.offset) { _, item in
                            let display = item.0
                            let url = item.1
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Image(systemName: "link")
                                        .font(.caption)
                                    Text(display)
                                        .font(.caption)
                                        .lineLimit(1)
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
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.05))
                    )
                }
            }
        }
    }

    private func extractVideoURLs(from text: String) -> [URL] {
        let pattern = #"https://(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/|vimeo\.com/)[\w\-]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return URL(string: String(text[range]))
        }
    }

    private static let allowedSchemes: Set<String> = ["https"]

    private func extractLinks(from text: String) -> [(String, URL)] {
        let pattern = #"https://[^\s<>\"\)]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let urlString = String(text[range])
            guard let url = URL(string: urlString),
                  let scheme = url.scheme?.lowercased(),
                  Self.allowedSchemes.contains(scheme)
            else { return nil }
            // Trim to display domain + path
            let display = url.host.map { host in
                let path = url.path.count > 1 ? url.path.prefix(30) : ""
                return "\(host)\(path)"
            } ?? urlString
            return (display, url)
        }
    }
}

// MARK: - Video Embed

struct VideoEmbedView: View {
    let url: URL

    private var thumbnailURL: URL? {
        let urlString = url.absoluteString
        // YouTube
        if urlString.contains("youtube.com") || urlString.contains("youtu.be") {
            let videoId: String? = if urlString.contains("youtu.be/") {
                url.lastPathComponent
            } else {
                URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "v" })?.value
            }
            if let id = videoId, id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) {
                return URL(string: "https://img.youtube.com/vi/\(id)/mqdefault.jpg")
            }
        }
        return nil
    }

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                if let thumbnail = thumbnailURL {
                    AsyncImage(url: thumbnail) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } placeholder: {
                        videoPlaceholder
                    }
                } else {
                    videoPlaceholder
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Video")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    Text(url.host ?? url.absoluteString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.3))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private var videoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 80, height: 50)
            .overlay(
                Image(systemName: "play.fill")
                    .foregroundStyle(.secondary)
            )
    }
}
