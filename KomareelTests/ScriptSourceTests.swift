import KomareelSourceKit
import Foundation
import Testing
import UIKit
import ZIPFoundation
@testable import Komareel

struct ScriptSourceTests {
    @MainActor
    @Test("A script streams home and detail updates through its own request")
    func streamsHomeAndDetailUpdates() async throws {
        let id = "tests.progress-" + UUID().uuidString.lowercased()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let script = """
        globalThis.source = {
          async home() {
            await Komareel.publish({ component: { title: "First", value: { links: { _0: [] } } } });
            await Komareel.publish({ component: { title: "Second", value: { links: { _0: [] } } } });
          },
          async details({ manga }) {
            await Komareel.publish({ details: { key: manga.key, title: "Updated " + manga.key } });
            await Komareel.publish({ chapters: [{ key: manga.key + "-chapter" }] });
          },
          processPage({ imageBase64 }) { return imageBase64; }
        };
        """
        let package = try makePackage(in: directory, id: id, version: 1, script: script, exports: ["home", "processPage"])
        let payload = directory.appendingPathComponent("unpacked")
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        try KomareelSourcePackage.unpack(package, to: payload)
        let source = try ScriptSourceRunner.makeSource(at: payload.appendingPathComponent("Payload"))

        var homeEvents: [[String]] = []
        let home = try await source.getHome { progress in homeEvents.append(progress.components.compactMap(\.title)) }
        #expect(homeEvents == [["First"], ["First", "Second"]])
        #expect(home.components.compactMap(\.title) == ["First", "Second"])

        var firstEvents: [KomareelSourceKit.Manga] = []
        var secondEvents: [KomareelSourceKit.Manga] = []
        let first = KomareelSourceKit.Manga(sourceKey: id, key: "one", title: "One")
        let second = KomareelSourceKit.Manga(sourceKey: id, key: "two", title: "Two")
        async let one = source.getMangaUpdate(manga: first, needsDetails: true, needsChapters: true) { firstEvents.append($0) }
        async let two = source.getMangaUpdate(manga: second, needsDetails: true, needsChapters: true) { secondEvents.append($0) }
        let final = try await (one, two)
        #expect(firstEvents.map(\.key) == ["one", "one"])
        #expect(secondEvents.map(\.key) == ["two", "two"])
        #expect(final.0.title == "Updated one")
        #expect(final.1.chapters?.first?.key == "two-chapter")
        #expect(final.1.chapters?.first?.language == "en")

        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image {
            UIColor.blue.setFill()
            $0.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        let descriptor = try await source.store(value: try #require(image.pngData()))
        let response = KomareelSourceKit.Response(code: 200, headers: [:], request: .init(url: nil, headers: [:]), image: descriptor)
        let processed = try await source.processPageImage(response: response, context: nil)
        #expect(processed?.cgImage?.width == image.cgImage?.width)
        try await source.remove(value: descriptor)
        #expect(try await source.processPageImage(response: response, context: nil) == nil)
    }

    @Test("A .krx source runs its script and a broken update preserves the installed version")
    func importsAndUpdatesScriptSource() async throws {
        let id = "tests.krx-" + UUID().uuidString.lowercased()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let script = """
        globalThis.source = {
          async search() {
            const value = await Komareel.webView({ html: "<p>New source</p>", expression: "document.querySelector('p').textContent" });
            return { entries: [{ key: "article", title: value }], hasNextPage: false };
          },
          details() { return { chapters: [{ key: "body", title: "Read" }] }; },
          pages() { return [{ text: Komareel.xpath("<p>Reader text</p>", "/p") }]; }
        };
        """
        let first = try makePackage(in: directory, id: id, version: 1, script: script)
        let broken = try makePackage(in: directory, id: id, version: 2, script: "globalThis.source = {")
        let second = try makePackage(in: directory, id: id, version: 3, script: script)
        let manager = SourceManager.shared

        do {
            let installed = await manager.importSource(from: first)
            let source = try #require(installed)
            let result = try await source.getSearchMangaList(query: nil, page: 1, filters: [])
            let manga = try #require(result.entries.first)
            #expect(manga.sourceKey == id)
            #expect(manga.title == "New source")
            let details = try await source.getMangaUpdate(manga: manga, needsDetails: false, needsChapters: true)
            let chapter = try #require(details.chapters?.first)
            #expect(try await source.getPageList(manga: details, chapter: chapter).first?.content == .text("Reader text"))

            #expect(await manager.importSource(from: broken) == nil)
            #expect(await manager.source(for: id)?.version == 1)
            #expect(await manager.importSource(from: second)?.version == 3)
            #expect(await manager.source(for: id)?.version == 3)
        } catch {
            await manager.remove(sourceKey: id)
            throw error
        }
        await manager.remove(sourceKey: id)
    }

    @Test("The script host decodes an API response and renders novel markup")
    func cryptoAndMarkdown() async throws {
        let code = """
        globalThis.source = {
          test: () => [
            Komareel.md5("abc"),
            Komareel.decryptAES256ECB("vXBxfBrEWqEoENv7PK2HVw==", "0123456789abcdef0123456789abcdef"),
            Komareel.markdown('<p>A*B<br>Second</p><img src="/sample.png">', "https://fixture.example")
          ]
        };
        """
        let script = SourceScript(key: "tests.transforms", code: code)
        let result = try await script.call("test", arguments: [String](), as: [String].self)
        #expect(result[0] == "900150983cd24fb0d6963f7d28e17f72")
        #expect(result[1] == "{\"ok\":true}")
        #expect(result[2] == "A\\*B\n\nSecond\n\n![](<https://fixture.example/sample.png>)")
        #expect(ScriptTransforms.decryptAES256ECB(ciphertext: "invalid", key: "short") == nil)
    }

    @MainActor
    @Test("Image slicing reverses vertical order and retains remainder pixels")
    func reversesHorizontalSlices() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3, height: 5), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3, height: 2))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 2, width: 3, height: 3))
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manifest = """
        {"scriptAPI":1,"imageProcessorInput":"metadata","exports":["processPage"],
         "info":{"id":"tests.slices","name":"Slices","version":1,"languages":["en"]}}
        """
        let script = """
        globalThis.source = {
          processPage(input) {
            if ("imageBase64" in input) throw Error("Metadata-only operation received image bytes.");
            return { reverseHorizontalSlices: 2 };
          }
        };
        """
        try manifest.write(to: directory.appendingPathComponent("source.json"), atomically: true, encoding: .utf8)
        try script.write(to: directory.appendingPathComponent("main.js"), atomically: true, encoding: .utf8)
        let source = try ScriptSourceRunner.makeSource(at: directory)
        let imageID = try await source.store(value: image)
        let response = KomareelSourceKit.Response(code: 200, headers: [:], request: .init(url: nil, headers: [:]), image: imageID)
        let transformed = try await source.processPageImage(response: response, context: nil)
        try await source.remove(value: imageID)
        let decoded = try #require(transformed?.cgImage)
        #expect(decoded.height == 5)
        for (row, blue) in [(0, true), (2, true), (3, false), (4, false)] {
            let pixel = try #require(decoded.cropping(to: CGRect(x: 0, y: row, width: 1, height: 1)))
            var rgba = [UInt8](repeating: 0, count: 4)
            rgba.withUnsafeMutableBytes { bytes in
                let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                context?.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            #expect(rgba[blue ? 2 : 0] > 200)
            #expect(rgba[blue ? 0 : 2] < 30)
        }
    }

    private func makePackage(in directory: URL, id: String, version: Int, script: String, exports: [String] = []) throws -> URL {
        let url = directory.appendingPathComponent("\(version).krx")
        let archive = try Archive(url: url, accessMode: .create)
        let exportsJSON = String(decoding: try JSONEncoder().encode(exports), as: UTF8.self)
        let manifest = """
        {"scriptAPI":1,"info":{"id":"\(id)","name":"Script Test","version":\(version),"languages":["en"]},"exports":\(exportsJSON)}
        """
        for (name, value) in [("source.json", manifest), ("main.js", script)] {
            let data = Data(value.utf8)
            try archive.addEntry(
                with: "Payload/" + name,
                type: .file,
                uncompressedSize: Int64(data.count),
                provider: { position, size in data.subdata(in: Int(position)..<Int(position) + size) }
            )
        }
        return url
    }
}
