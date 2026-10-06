import Foundation

/// Append-only decision log for debugging what got tracked and why. Rotates at 5 MB (one backup).
enum Log {
    static let file = DB.dir.appendingPathComponent("tracker.log")
    private static let queue = DispatchQueue(label: "timetracker.log")
    private static let fmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f }()

    static func write(_ category: String, _ message: String) {
        let line = "\(fmt.string(from: Date())) [\(category)] \(message)\n"
        queue.async {
            if let size = try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int, size > 5_000_000 {
                try? FileManager.default.removeItem(atPath: file.path + ".1")
                try? FileManager.default.moveItem(atPath: file.path, toPath: file.path + ".1")
            }
            if let h = try? FileHandle(forWritingTo: file) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
            else { try? line.write(to: file, atomically: true, encoding: .utf8) }
        }
    }
}
