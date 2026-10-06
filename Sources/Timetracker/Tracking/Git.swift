import Foundation

/// Git facts read straight from the repo: its root, current branch and commits.
enum Git {
    /// Walks up from `path` until a `.git` entry is found.
    static func root(of path: String) -> String? {
        var u = URL(fileURLWithPath: path)
        while u.path != "/" {
            if FileManager.default.fileExists(atPath: u.appendingPathComponent(".git").path) { return u.path }
            u.deleteLastPathComponent()
        }
        return nil
    }
    static func branch(of root: String) -> String? {
        guard let head = try? String(contentsOfFile: root + "/.git/HEAD", encoding: .utf8) else { return nil }
        let t = head.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("ref: refs/heads/") ? String(t.dropFirst(16)) : String(t.prefix(8))
    }

    /// Commits authored in `range`, oldest first. Empty if git or the repo is unavailable.
    static func commits(in repo: String, during range: Interval) -> [(ts: Seconds, subject: String)] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", repo, "log", "--all", "--reverse", "--since=@\(Int(range.start))", "--until=@\(Int(range.end))", "--format=%at\t%s"]
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        guard (try? p.run()) != nil else { return [] }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, let ts = Double(parts[0]) else { return nil }
            return (ts, String(parts[1]))
        }
    }
}
