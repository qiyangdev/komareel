//
//  BackupHistory.swift
//  Aidoku
//
//  Created by Skitty on 2/26/22.
//

import CoreData

struct BackupHistory: Codable, Hashable {
    var dateRead: Date
    var sourceId: String
    var chapterId: String
    var mangaId: String
    var progress: Int?
    var total: Int?
    var completed: Bool
    var videoPosition: Double?
    var videoDuration: Double?

    init(historyObject: HistoryObject) {
        dateRead = historyObject.dateRead ?? Date.distantPast
        sourceId = historyObject.sourceId
        chapterId = historyObject.chapterId
        mangaId = historyObject.mangaId
        progress = Int(historyObject.progress)
        total = Int(historyObject.total)
        completed = historyObject.completed
        videoPosition = historyObject.videoPosition?.doubleValue
        videoDuration = historyObject.videoDuration?.doubleValue
    }

    func toObject(context: NSManagedObjectContext) -> HistoryObject {
        let obj = HistoryObject(context: context)
        obj.dateRead = dateRead
        obj.sourceId = sourceId
        obj.chapterId = chapterId
        obj.mangaId = mangaId
        obj.progress = Int16(progress ?? -1)
        obj.total = Int16(total ?? 0)
        obj.completed = completed
        obj.videoPosition = videoPosition.map { NSNumber(value: $0) }
        obj.videoDuration = videoDuration.map { NSNumber(value: $0) }
        return obj
    }
}
