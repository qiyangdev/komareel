//
//  MangaUpdateManager.swift
//  Aidoku
//
//  Created by axiel7 on 17/03/2024.
//

import KomareelSourceKit
import CoreData

struct MangaUpdateManager {
    static let shared = MangaUpdateManager()
}

extension MangaUpdateManager {
    func viewAllUpdates(of manga: KomareelSourceKit.Manga) async {
        await CoreDataManager.shared.container.performBackgroundTask { context in
            let updates = CoreDataManager.shared.setMangaUpdatesViewed(
                mangaId: manga.identifier,
                context: context
            )
            if !updates.isEmpty {
                NotificationCenter.default.post(name: .mangaUpdatesViewed, object: updates.map { $0.toItem() })
            }
        }
    }
}
