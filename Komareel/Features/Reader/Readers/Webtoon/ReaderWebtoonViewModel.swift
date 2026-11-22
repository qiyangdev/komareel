//
//  ReaderWebtoonViewModel.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 9/27/22.
//

import KomareelSourceKit
import Foundation

@MainActor
class ReaderWebtoonViewModel: ReaderPagedViewModel {
    func setPages(chapter: KomareelSourceKit.Chapter, pages: [Page]) {
        self.chapter = chapter
        self.pages = pages
        if preloadedChapter == chapter {
            preloadedPages = []
        }
    }
}
