//
//  SettingSearchResult.swift
//  Aidoku
//
//  Created by Skitty on 9/19/25.
//

import KomareelSourceKit
import SwiftUI

struct SettingPath {
    let key: String
    let title: String
    let paths: [String]
    var setting: KomareelSourceKit.Setting?
}

struct SettingSearchResult {
    var sections: [Section]

    struct Section: Identifiable {
        let id = UUID()
        var icon: KomareelSourceKit.PageSetting.Icon?
        var header: String?
        var paths: [SettingPath]
    }
}
