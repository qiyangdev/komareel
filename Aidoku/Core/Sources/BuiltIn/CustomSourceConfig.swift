//
//  CustomSourceConfig.swift
//  Aidoku
//
//  Created by Skitty on 5/25/25.
//

import KomareelSourceKit
import Foundation

enum CustomSourceConfig {
    case demo
    case local
    case sampleVideo
    case komga(KeyNameServer)
    case kavita(KeyNameServer)
    case suwayomi(KeyNameServer)

    struct KeyNameServer {
        let key: String
        let name: String
        let server: String
    }
}

extension CustomSourceConfig {
    func toSource() -> KomareelSourceKit.Source {
        switch self {
            case .demo:
                .demo()
            case .local:
                .local()
            case .sampleVideo:
                .sampleVideo()
            case let .komga(config):
                .komga(key: config.key, name: config.name, server: config.server)
            case let .kavita(config):
                .kavita(key: config.key, name: config.name, server: config.server)
            case let .suwayomi(config):
                .suwayomi(key: config.key, name: config.name, server: config.server)
        }
    }
}

// MARK: Coding
extension CustomSourceConfig {
    init(from data: Data) throws {
        guard data.count >= 1 else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Invalid byte count"
            ))
        }

        var currentIndex = 1

        func decodeString() throws -> String {
            let length: UInt64 = try decodeVarInt(data, currentIndex: &currentIndex)
            guard let count = Int(exactly: length), count <= data.endIndex - currentIndex else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Invalid string length")
                )
            }
            let endIndex = currentIndex + count
            let stringData = data[currentIndex..<endIndex]
            currentIndex = endIndex
            return String(data: stringData, encoding: .utf8) ?? ""
        }

        switch data[0] {
            case 0:
                self = .demo
            case 1:
                let key = try decodeString()
                let name = try decodeString()
                let server = try decodeString()
                self = .komga(.init(key: key, name: name, server: server))
            case 2:
                self = .local
            case 3:
                let key = try decodeString()
                let name = try decodeString()
                let server = try decodeString()
                self = .kavita(.init(key: key, name: name, server: server))
            case 4:
                let key = try decodeString()
                let name = try decodeString()
                let server = try decodeString()
                self = .suwayomi(.init(key: key, name: name, server: server))
            case 5:
                self = .sampleVideo
            default:
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [],
                    debugDescription: "Invalid type"
                ))
        }
    }

    func encode() -> Data {
        var bytes = Data()

        switch self {
            case .demo:
                bytes.append(0)
            case let .komga(config):
                bytes.append(1)
                for string in [config.key, config.name, config.server] {
                    let utf8 = [UInt8](string.utf8)
                    varInt(UInt64(utf8.count), data: &bytes)
                    bytes.append(contentsOf: utf8)
                }
            case .local:
                bytes.append(2)
            case .sampleVideo:
                bytes.append(5)
            case let .kavita(config):
                bytes.append(3)
                for string in [config.key, config.name, config.server] {
                    let utf8 = [UInt8](string.utf8)
                    varInt(UInt64(utf8.count), data: &bytes)
                    bytes.append(contentsOf: utf8)
                }
            case let .suwayomi(config):
                bytes.append(4)
                for string in [config.key, config.name, config.server] {
                    let utf8 = [UInt8](string.utf8)
                    varInt(UInt64(utf8.count), data: &bytes)
                    bytes.append(contentsOf: utf8)
                }
        }

        return bytes
    }
}

private func varInt(_ input: UInt64, data: inout Data) {
    var value = input
    while value >= 128 {
        data.append(UInt8(value & 127) | 128)
        value >>= 7
    }
    data.append(UInt8(value))
}

private func decodeVarInt(_ data: Data, currentIndex: inout Int) throws -> UInt64 {
    var value: UInt64 = 0
    for shift in stride(from: 0, through: 63, by: 7) {
        guard currentIndex < data.endIndex else { break }
        let byte = data[currentIndex]
        currentIndex += 1
        guard shift < 63 || byte <= 1 else { break }
        value |= UInt64(byte & 127) << shift
        if byte < 128 { return value }
    }
    throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid length prefix"))
}
