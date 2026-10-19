import Foundation

/// Only display data is shared with WidgetKit. Credentials stay in the host app.
public struct ControlSharedStore {
    private let url: URL

    public init(directory: URL) { url = directory.appendingPathComponent("favorites.json") }

    public static func configured(bundle: Bundle = .main) -> ControlSharedStore? {
        configuredDirectory(bundle: bundle).map(ControlSharedStore.init)
    }

    public static func configuredDirectory(bundle: Bundle = .main) -> URL? {
        guard let group = bundle.object(forInfoDictionaryKey: "HomeControlAppGroup") as? String,
              !group.isEmpty, !group.contains("$("),
              let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
        return directory
    }

    public func read() throws -> FavoriteControlSnapshot {
        try JSONDecoder().decode(FavoriteControlSnapshot.self, from: Data(contentsOf: url))
    }

    public func write(_ snapshot: FavoriteControlSnapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public static func isFresh(_ snapshot: FavoriteControlSnapshot, now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(snapshot.updatedAt)
        return snapshot.connected && age >= -5 && age < 90
    }
}
