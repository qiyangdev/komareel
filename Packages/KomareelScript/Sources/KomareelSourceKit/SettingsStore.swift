import CryptoKit
import Foundation
import SwiftUI
import WebKit

public final class SettingsStore: Sendable {
    public static let shared = SettingsStore()
    private init() {}

    public func set<T>(key: String, value: T) {
        setValue(key: key, value: value)
    }

    public func setValue(key: String, value: Any?) {
        UserDefaults.standard.set(value, forKey: key)
    }

    public func remove(key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }

    public func get(key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
    public func get(key: String) -> Int { UserDefaults.standard.integer(forKey: key) }
    public func get(key: String) -> Double { UserDefaults.standard.double(forKey: key) }
    public func get(key: String) -> String { UserDefaults.standard.string(forKey: key) ?? "" }
    public func get(key: String) -> [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }
    public func get(key: String) -> Data? { UserDefaults.standard.data(forKey: key) }
    public func object(key: String) -> Any? { UserDefaults.standard.object(forKey: key) }

    public func register(key: String, default value: Any) {
        UserDefaults.standard.register(defaults: [key: value])
    }

    public func binding(key: String) -> Binding<Bool> { Binding(get: { self.get(key: key) }, set: { self.set(key: key, value: $0) }) }
    public func binding(key: String) -> Binding<Int> { Binding(get: { self.get(key: key) }, set: { self.set(key: key, value: $0) }) }
    public func binding(key: String) -> Binding<Double> { Binding(get: { self.get(key: key) }, set: { self.set(key: key, value: $0) }) }
    public func binding(key: String) -> Binding<String> { Binding(get: { self.get(key: key) }, set: { self.set(key: key, value: $0) }) }
    public func binding(key: String) -> Binding<[String]> { Binding(get: { self.get(key: key) }, set: { self.set(key: key, value: $0) }) }
}

public extension WKWebsiteDataStore {
    @MainActor static func forSource(key: String) -> WKWebsiteDataStore {
        // Preserve the identifier of existing source sessions.
        var bytes = Array(Insecure.SHA1.hash(data: Data(key.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 15) | 80
        bytes[8] = (bytes[8] & 63) | 128
        let id = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return .init(forIdentifier: id)
    }

    @MainActor func clearRecords() async {
        await removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
    }
}
