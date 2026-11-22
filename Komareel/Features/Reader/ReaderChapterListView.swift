//
//  ReaderChapterListView.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 12/20/22.
//

import SwiftUI
import KomareelSourceKit

struct ReaderChapterListView: View {
    var chapterList: [KomareelSourceKit.Chapter]
    @State var chapter: KomareelSourceKit.Chapter
    var chapterSet: ((KomareelSourceKit.Chapter) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PlatformNavigationStack {
            ScrollViewReader { proxy in
                List(chapterList) { chapter in
                    Button {
                        self.chapter = chapter
                        chapterSet?(chapter)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(displayString(for: chapter))
                                    .foregroundColor(.primary)
                                    .font(.subheadline)
                                if let title = chapter.title, chapter.chapterNumber != nil || chapter.volumeNumber != nil {
                                    Text(title)
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                }
                            }
                            Spacer()
                            if chapter == self.chapter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .id(chapter.id)
                }
                .onAppear {
                    proxy.scrollTo(chapter.id, anchor: .center)
                }
            }
            .navigationTitle(NSLocalizedString("CHAPTERS"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
    }

    private func displayString(for chapter: KomareelSourceKit.Chapter) -> String {
        if let chapterNum = chapter.chapterNumber {
            if let volumeNum = chapter.volumeNumber {
                String(
                    format: NSLocalizedString("VOL_X") + " " + NSLocalizedString("CH_X"),
                    volumeNum,
                    chapterNum
                )
            } else {
                String(format: NSLocalizedString("CHAPTER_X"), chapterNum)
            }
        } else if let volumeNum = chapter.volumeNumber {
            String(format: NSLocalizedString("VOLUME_X"), volumeNum)
        } else {
            chapter.title ?? ""
        }
    }
}
