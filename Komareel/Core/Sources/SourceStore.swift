//
//  SourceStore.swift
//  Aidoku
//
//  Created by skitty on 8/25/26.
//

import KomareelSourceKit
import Foundation

@MainActor
final class SourceStore: ObservableObject {
    static let shared = SourceStore()

    @Published private(set) var sourcesByKey: [String: KomareelSourceKit.Source] = [:]
    @Published private(set) var disabledSourceKeys: Set<String> = []

    func update(
        sourcesByKey: [String: KomareelSourceKit.Source],
        disabledSourceKeys: Set<String>
    ) {
        self.sourcesByKey = sourcesByKey
        self.disabledSourceKeys = disabledSourceKeys
    }

    func source(for key: String) -> KomareelSourceKit.Source? {
        sourcesByKey[key]
    }

    func isInstalled(sourceKey: String) -> Bool {
        sourcesByKey[sourceKey] != nil
    }

    func isDisabled(sourceKey: String) -> Bool {
        disabledSourceKeys.contains(sourceKey)
    }

    var localSourceInstalled: Bool {
        sourcesByKey[LocalSourceRunner.sourceKey] != nil
    }
}
