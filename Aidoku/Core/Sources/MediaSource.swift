import AidokuRunner
import Foundation

enum SourceMediaType: String {
    case manga
    case video
    case audio
}

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
    @MainActor private static let mediaTypes = NSMapTable<AidokuRunner.Source, NSString>(
        keyOptions: [.weakMemory, .objectPointerPersonality],
        valueOptions: .strongMemory
    )

    @MainActor var mediaType: SourceMediaType {
        if runner is any VideoSourceRunner { return .video }
        guard isExternal, let url else { return .manga }
        if let cached = Self.mediaTypes.object(forKey: self) {
            return SourceMediaType(rawValue: cached as String) ?? .manga
        }

        let manifest = try? Data(contentsOf: url.appendingPathComponent("source.json"))
        let value = manifest.flatMap { try? JSONDecoder().decode(MediaManifest.self, from: $0) }?.config?.mediaType
        let type = value.flatMap(SourceMediaType.init(rawValue:)) ?? .manga
        Self.mediaTypes.setObject(type.rawValue as NSString, forKey: self)
        return type
    }

    @MainActor var isPlayableMedia: Bool { mediaType != .manga }

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
