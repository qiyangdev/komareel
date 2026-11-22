import Foundation
import UniformTypeIdentifiers
import ZIPFoundation

enum KomareelSourcePackage {
    static let fileExtension = "krx"
    static let contentType = UTType(exportedAs: "dev.qiyang.komareel.krx", conformingTo: .zip)

    static func matches(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == fileExtension
    }

    static func unpack(_ file: URL, to directory: URL) throws {
        let archive = try Archive(url: file, accessMode: .read)
        var paths: Set<String> = []
        var remaining: UInt64 = 32 * 1024 * 1024
        for entry in archive {
            let path = entry.path
            let parts = path.split(separator: "/", omittingEmptySubsequences: true)
            guard parts.first == "Payload", !path.hasPrefix("/"), !path.contains("\\"),
                  !parts.contains("."), !parts.contains(".."), entry.type != .symlink,
                  paths.insert(path).inserted, paths.count <= 256, entry.uncompressedSize <= remaining
            else { throw CocoaError(.fileReadCorruptFile) }
            remaining -= entry.uncompressedSize
        }
        guard paths.contains("Payload/main.js"), paths.contains("Payload/source.json") else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try FileManager.default.unzipItem(at: file, to: directory)
    }
}
