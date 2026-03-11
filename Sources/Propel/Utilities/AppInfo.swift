import Foundation

enum AppInfo {
    static let version = "1.0.0"
    static let buildNumber = "1"

    static var buildDate: String {
        // Compile-time date from __DATE__ equivalent
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        // Use the bundle's creation date as a proxy for build time
        if let url = Bundle.main.executableURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let date = attrs[.creationDate] as? Date
        {
            return formatter.string(from: date)
        }
        return formatter.string(from: Date())
    }

    static let copyright = "Copyright (c) 2026 Ran Isenberg"
    // swiftlint:disable:next force_unwrapping
    static let websiteURL = URL(string: "https://ranthebuilder.cloud")!
    // swiftlint:disable:next force_unwrapping
    static let githubURL = URL(string: "https://github.com/ran-isenberg")!
    static let license = "MIT License - Copyright (c) 2026 Ran Isenberg"
}
