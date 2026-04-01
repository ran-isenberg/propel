import Foundation

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

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

    static let websiteURL: URL = {
        guard let url = URL(string: "https://ranthebuilder.cloud") else {
            return URL(fileURLWithPath: "/")
        }
        return url
    }()

    static let githubURL: URL = {
        guard let url = URL(string: "https://github.com/ran-isenberg") else {
            return URL(fileURLWithPath: "/")
        }
        return url
    }()

    static let license = "MIT License - Copyright (c) 2026 Ran Isenberg"
}
