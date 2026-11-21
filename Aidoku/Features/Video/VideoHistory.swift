import AidokuRunner
import CoreData
import Foundation

struct VideoProgress: Sendable {
    let position: Double
    let duration: Double
    let completed: Bool
    let updatedAt: Date
}

@MainActor
enum VideoHistory {
    static func progress(for manga: MangaIdentifier) -> [String: VideoProgress] {
        let histories = CoreDataManager.shared.getHistoryForManga(mangaId: manga, context: CoreDataManager.shared.context)
        return Dictionary(histories.compactMap { history -> (String, VideoProgress)? in
            guard
                let position = history.videoPosition?.doubleValue,
                let duration = history.videoDuration?.doubleValue
            else { return nil }
            return (history.chapterId, .init(
                position: position, duration: duration, completed: history.completed,
                updatedAt: history.dateRead ?? .distantPast
            ))
        }, uniquingKeysWith: { $0.updatedAt >= $1.updatedAt ? $0 : $1 })
    }

    static func save(_ progress: VideoProgress, manga: AidokuRunner.Manga, episode: AidokuRunner.Chapter) -> Bool {
        guard !AppSettings.general.incognitoMode.get() else { return false }
        let database = CoreDataManager.shared
        let context = database.container.newBackgroundContext()
        let mangaId = manga.identifier
        let chapterId = ChapterIdentifier(sourceKey: mangaId.sourceKey, mangaKey: mangaId.mangaKey, chapterKey: episode.key)
        return context.performAndWait {
            let mangaObject = database.getOrCreateManga(manga, context: context)
            if !database.hasChapter(chapterId: chapterId, context: context) {
                database.createChapter(
                    episode, mangaId: mangaId, sourceOrder: manga.chapters?.firstIndex(where: { $0.key == episode.key }) ?? 0,
                    mangaObject: mangaObject, context: context
                )
            }
            let history = database.getOrCreateHistory(chapterId: chapterId, context: context)
            guard progress.updatedAt >= (history.dateRead ?? .distantPast) else { return false }
            history.dateRead = progress.updatedAt
            if !history.completed || progress.completed || history.videoPosition == nil {
                history.videoPosition = NSNumber(value: progress.position)
                history.videoDuration = NSNumber(value: progress.duration)
            }
            history.completed = history.completed || progress.completed
            database.setRead(mangaId: mangaId, date: progress.updatedAt, context: context)
            do {
                try context.save()
                return true
            } catch {
                LogManager.logger.error("Failed to save video history: \(error)")
                return false
            }
        }
    }
}
