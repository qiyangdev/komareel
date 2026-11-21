import AidokuRunner
import Foundation

enum SourceMediaType: String {
    case manga
    case text
    case video
    case audio
}

protocol VideoSourceRunner: AidokuRunner.Runner {
    func videoURL(manga: AidokuRunner.Manga, episode: AidokuRunner.Chapter) async throws -> URL
}

extension AidokuRunner.Source {
    private final class SourceManifest: Decodable {
        struct Configuration: Decodable {
            let mediaType: String?
            let showsListCovers: Bool?
        }

        let config: Configuration?

        init() {
            config = nil
        }
    }

    // Cache by loaded source instance so reinstalling a package reads its new manifest.
    @MainActor private static let sourceManifests = NSMapTable<AidokuRunner.Source, SourceManifest>(
        keyOptions: [.weakMemory, .objectPointerPersonality],
        valueOptions: .strongMemory
    )

    @MainActor private var manifestConfiguration: SourceManifest.Configuration? {
        guard isExternal, let url else { return nil }
        if let cached = Self.sourceManifests.object(forKey: self) {
            return cached.config
        }

        let data = try? Data(contentsOf: url.appendingPathComponent("source.json"))
        let manifest = data.flatMap { try? JSONDecoder().decode(SourceManifest.self, from: $0) } ?? SourceManifest()
        Self.sourceManifests.setObject(manifest, forKey: self)
        return manifest.config
    }

    @MainActor var mediaType: SourceMediaType {
        if runner is any VideoSourceRunner { return .video }
        return manifestConfiguration?.mediaType.flatMap(SourceMediaType.init(rawValue:)) ?? .manga
    }

    @MainActor var showsListCovers: Bool { manifestConfiguration?.showsListCovers ?? true }

    @MainActor var isPlayableMedia: Bool {
        let type = mediaType
        return type == .audio || type == .video
    }

    @MainActor
    func playbackURL(manga: AidokuRunner.Manga, episode: AidokuRunner.Chapter) async throws -> URL {
        if let runner = runner as? any VideoSourceRunner {
            return try await runner.videoURL(manga: manga, episode: episode)
        }
        guard isPlayableMedia else { throw SourceError.unimplemented }

        // Audio and video packages resolve one stream per episode through the existing WASM ABI.
        let pages = try await getPageList(manga: manga, chapter: episode)
        guard pages.count == 1, let page = pages.first, case let .url(url, _) = page.content else {
            throw URLError(.unsupportedURL)
        }
        return url
    }
}
