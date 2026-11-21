import AidokuRunner
import Foundation

protocol VideoSourceRunner: AidokuRunner.Runner {
    func videoURL(manga: AidokuRunner.Manga, episode: AidokuRunner.Chapter) async throws -> URL
}

extension AidokuRunner.Source {
    private struct MediaManifest: Decodable {
        struct Configuration: Decodable {
            let mediaType: String?
        }

        let config: Configuration?
    }

    // Cache by loaded source instance so reinstalling a package reads its new manifest.
    @MainActor private static let videoSources = NSMapTable<AidokuRunner.Source, NSNumber>(
        keyOptions: [.weakMemory, .objectPointerPersonality],
        valueOptions: .strongMemory
    )

    @MainActor var isVideoSource: Bool {
        if runner is any VideoSourceRunner { return true }
        guard isExternal, let url else { return false }
        if let cached = Self.videoSources.object(forKey: self) { return cached.boolValue }

        let manifest = try? Data(contentsOf: url.appendingPathComponent("source.json"))
        let mediaType = manifest.flatMap { try? JSONDecoder().decode(MediaManifest.self, from: $0) }?.config?.mediaType
        let isVideo = mediaType == "video"
        Self.videoSources.setObject(NSNumber(value: isVideo), forKey: self)
        return isVideo
    }

    @MainActor
    func videoURL(manga: AidokuRunner.Manga, episode: AidokuRunner.Chapter) async throws -> URL {
        if let runner = runner as? any VideoSourceRunner {
            return try await runner.videoURL(manga: manga, episode: episode)
        }
        guard isVideoSource else { throw SourceError.unimplemented }

        // Video packages use the existing get_page_list ABI to resolve one stream per episode.
        let pages = try await getPageList(manga: manga, chapter: episode)
        guard pages.count == 1, let page = pages.first, case let .url(url, _) = page.content else {
            throw URLError(.unsupportedURL)
        }
        return url
    }
}
