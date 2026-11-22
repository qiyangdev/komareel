//
//  SourceObject.swift
//  Aidoku
//
//  Created by Skitty on 2/14/22.
//

import KomareelSourceKit
import CoreData

extension SourceObject {
    func load(from source: KomareelSourceKit.Source) {
        id = source.key
        apiVersion = if source.runner is ScriptSourceRunner {
            "krx/1"
        } else {
            source.apiVersion
        }
        if let url = source.url {
            path = url.pathComponents[url.pathComponents.count - 2..<url.pathComponents.count]
                .joined(separator: "/")
        }
    }

    func toData() -> SourceObjectData {
        .init(
            objectID: objectID,
            id: id ?? "",
            apiVersion: apiVersion,
            path: path,
            listing: listing,
            customSource: customSource as? Data
        )
    }
}

struct SourceObjectData: Sendable {
    let objectID: NSManagedObjectID
    let id: String
    let apiVersion: String?
    let path: String?
    let listing: Int16
    let customSource: Data?
}

extension SourceObjectData {
    func toNewSource() async -> KomareelSourceKit.Source? {
        if let data = customSource, let config = try? CustomSourceConfig(from: data) {
            return config.toSource()
        }
        if let path {
            let url = FileManager.default.applicationSupportDirectory.appendingPathComponent(path)
            return try? ScriptSourceRunner.makeSource(at: url)
        }
        return nil
    }

    func toInfo() -> SourceInfo? {
        if let data = customSource, let config = try? CustomSourceConfig(from: data) {
            return config.toSource().toInfo()
        }
        guard let path else { return nil }

        let url = FileManager.default.applicationSupportDirectory.appendingPathComponent(path)
        let iconUrl = url.appendingPathComponent("icon.png")
        if
            let data = try? Data(contentsOf: url.appendingPathComponent("source.json")),
            let sourceInfo = try? JSONDecoder().decode(KomareelSourceKit.SourceInfo.self, from: data)
        {
            return .init(
                sourceId: id,
                iconUrl: iconUrl,
                name: sourceInfo.info.name,
                altNames: sourceInfo.info.altNames ?? [],
                urls: sourceInfo.info.urls ?? sourceInfo.info.url.flatMap { [$0] } ?? [],
                languages: sourceInfo.info.languages,
                version: sourceInfo.info.version,
                contentRating: sourceInfo.info.contentRating ?? .safe,
                external: false,
                externalInfo: nil
            )
        }
        return nil
    }
}
