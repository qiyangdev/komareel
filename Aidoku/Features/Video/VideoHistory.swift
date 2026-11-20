import Foundation

struct VideoProgress: Codable {
    let position: Double
    let duration: Double
    let completed: Bool
    let updatedAt: Date
}

@MainActor
enum VideoHistory {
    static func progress(for manga: MangaIdentifier) -> [String: VideoProgress] {
        guard let data = UserDefaults.standard.data(forKey: storageKey(for: manga)) else { return [:] }
        return (try? JSONDecoder().decode([String: VideoProgress].self, from: data)) ?? [:]
    }

    static func save(_ progress: VideoProgress, manga: MangaIdentifier, episodeKey: String) {
        guard !AppSettings.general.incognitoMode.get() else { return }
        var episodes = Self.progress(for: manga)
        episodes[episodeKey] = progress
        if let data = try? JSONEncoder().encode(episodes) {
            UserDefaults.standard.set(data, forKey: storageKey(for: manga))
        }
    }

    private static func storageKey(for manga: MangaIdentifier) -> String {
        "VideoHistory.\(manga.sourceKey.utf8.count).\(manga.sourceKey)\(manga.mangaKey)"
    }
}
