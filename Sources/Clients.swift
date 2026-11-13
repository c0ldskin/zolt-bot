import Foundation

/// What Zolt remembers about each client between calls. Every client gets a folder inside the
/// meeting notes folder, holding the notes of each call with them and a short `memory.md` that is
/// rewritten after every call: who the people are, what they want, what worries them, what was
/// promised and what happens next. It's plain Markdown on this Mac, so you can read and fix it.
final class Clients {
    static let shared = Clients(folder: robot.notesFolder.appendingPathComponent("Clients"))
    /// The memory goes to Claude with every suggested answer, so it stays short.
    static let maxMemoryLength = 6_000
    private static let maxNameLength = 60

    private let folder: URL

    init(folder: URL) { self.folder = folder }

    /// Known clients, most recently used first.
    var names: [String] {
        let found = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                                                                  options: [.skipsHiddenFiles])) ?? []
        return found.compactMap { url -> (String, Date)? in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]), values.isDirectory == true else { return nil }
            return (url.lastPathComponent, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    func folder(for name: String) -> URL { folder.appendingPathComponent(name, isDirectory: true) }

    private func memoryFile(_ name: String) -> URL { folder(for: name).appendingPathComponent("memory.md") }

    /// A client name that is safe to use as a folder name; nil if nothing usable is left.
    static func clean(_ name: String) -> String? {
        let swapped = String(name.map { "/:\\".contains($0) || $0.isNewline ? "-" : $0 })
        let trimmed = swapped.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".")))
        let short = String(trimmed.prefix(maxNameLength)).trimmingCharacters(in: .whitespaces)
        return short.isEmpty ? nil : short
    }

    /// Creates the client's folder and returns the name it was stored under.
    func add(_ name: String) -> String? {
        guard let safe = Clients.clean(name) else { return nil }
        // Reuse an existing client that differs only by capitals, so "Acme" and "acme" don't split.
        if let existing = names.first(where: { $0.caseInsensitiveCompare(safe) == .orderedSame }) { return existing }
        do {
            try FileManager.default.createDirectory(at: folder(for: safe), withIntermediateDirectories: true)
            return safe
        } catch {
            return nil
        }
    }

    /// What's remembered about a client; empty before the first call.
    func memory(for name: String) -> String {
        let text = (try? String(contentsOf: memoryFile(name), encoding: .utf8)) ?? ""
        return String(text.prefix(Clients.maxMemoryLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    func remember(_ name: String, _ text: String) -> Bool {
        let body = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Clients.maxMemoryLength))
        guard !body.isEmpty else { return false }
        do {
            try FileManager.default.createDirectory(at: folder(for: name), withIntermediateDirectories: true)
            try (body + "\n").write(to: memoryFile(name), atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    /// The memory as a passage for suggested answers, labelled like a briefing source.
    func passage(for name: String) -> String {
        let text = memory(for: name)
        guard !text.isEmpty else { return "" }
        // Remembered text can't close the tag that marks it as reference material.
        let label = name.replacingOccurrences(of: "]", with: ")")
        return "[Past calls with \(label)]\n" + text.replacingOccurrences(of: "</briefing", with: "", options: .caseInsensitive)
    }
}
