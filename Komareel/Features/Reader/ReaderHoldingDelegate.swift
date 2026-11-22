//
//  ReaderHoldingDelegate.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 8/16/22.
//

import Foundation
import KomareelSourceKit

protocol ReaderHoldingDelegate: AnyObject {
    var barsHidden: Bool { get }

    func hideBars()

    func getNextChapter() -> KomareelSourceKit.Chapter?
    func getPreviousChapter() -> KomareelSourceKit.Chapter?
    func setChapter(_ chapter: KomareelSourceKit.Chapter)

    func setCurrentPage(_ page: Int, position: Double?)
    func setCurrentPages(_ pages: ClosedRange<Int>)
    func setPages(_ pages: [Page])
    func displayPage(_ page: Int) // show page on toolbar but don't set it as current page
    func setSliderOffset(_ offset: CGFloat)
    func setCompleted()
}
