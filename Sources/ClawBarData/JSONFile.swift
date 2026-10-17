import Foundation
import ClawBarShared

/// Small helpers for the flat JSON files ClawBar owns.
enum JSONFile {
    /// The file's top-level object; nil when it is missing, unreadable or not an object. A UTF-8 BOM is skipped.
    static func object(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return object(from: data)
    }

    static func object(from data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: withoutBOM(data))) as? [String: Any]
    }

    static func withoutBOM(_ data: Data) -> Data {
        data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data
    }

    /// Pretty, key-sorted and atomic (temp file + rename), creating the folder when needed.
    static func write(_ object: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        data.append(0x0A)
        try data.write(to: url, options: .atomic)
    }
}
