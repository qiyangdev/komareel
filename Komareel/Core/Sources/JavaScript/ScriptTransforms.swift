import CommonCrypto
import CryptoKit
import Foundation
import SwiftSoup
import UIKit

enum ScriptTransforms {
    static func md5(_ value: String) -> String {
        Insecure.MD5.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func decryptAES256ECB(ciphertext: String, key: String) -> String? {
        let keyBytes = Data(key.utf8)
        guard keyBytes.count == kCCKeySizeAES256,
              let bytes = Data(base64Encoded: ciphertext), !bytes.isEmpty,
              bytes.count.isMultiple(of: kCCBlockSizeAES128)
        else { return nil }
        var result = Data(count: bytes.count)
        var count = 0
        let capacity = result.count
        let status = result.withUnsafeMutableBytes { output in
            bytes.withUnsafeBytes { input in
                keyBytes.withUnsafeBytes { key in
                    CCCrypt(
                        CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding),
                        key.baseAddress, key.count, nil, input.baseAddress, input.count, output.baseAddress, capacity, &count
                    )
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return String(data: result.prefix(count), encoding: .utf8)
    }

    static func markdown(_ html: String, baseURL: URL) throws -> String {
        let document = try SwiftSoup.parseBodyFragment(html, baseURL.absoluteString)
        var blocks: [String] = []
        var line = ""

        func finishLine() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let escaped = trimmed.reduce(into: "") { result, character in
                    if character.isASCII, character.isPunctuation || character.isSymbol { result.append("\\") }
                    result.append(character)
                }
                blocks.append(escaped)
            }
            line = ""
        }

        func visit(_ node: Node) {
            if let text = node as? TextNode {
                line += text.getWholeText()
                return
            }
            guard let element = node as? Element else { return }
            switch element.tagName() {
                case "br":
                    finishLine()
                case "img":
                    finishLine()
                    if let path = try? element.absUrl("src"), let url = URL(string: path),
                       ["https", "http"].contains(url.scheme ?? ""), url.host != nil {
                        blocks.append("![](<\(url.absoluteString)>)")
                    }
                case "script", "style":
                    break
                case "p":
                    finishLine()
                    element.getChildNodes().forEach(visit)
                    finishLine()
                default:
                    element.getChildNodes().forEach(visit)
            }
        }

        document.body()?.getChildNodes().forEach(visit)
        finishLine()
        return blocks.joined(separator: "\n\n")
    }

    static func reverseHorizontalSlices(_ image: UIImage, count: Int) -> UIImage? {
        guard let source = image.cgImage, (2...64).contains(count), count <= source.height else { return nil }
        let stride = source.height / count
        let extra = source.height % count
        let size = CGSize(width: source.width, height: source.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            var destinationY = 0
            for index in (0..<count).reversed() {
                let height = stride + (index == count - 1 ? extra : 0)
                let sourceRect = CGRect(x: 0, y: index * stride, width: source.width, height: height)
                if let slice = source.cropping(to: sourceRect) {
                    UIImage(cgImage: slice).draw(in: CGRect(x: 0, y: destinationY, width: source.width, height: height))
                }
                destinationY += height
            }
        }
    }
}
