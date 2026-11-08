import Cocoa
import PDFKit
import UniformTypeIdentifiers

/// Documents and web pages you hand over before a call. They're turned into plain text once and
/// kept in ~/.zolt/briefing. When someone asks a question, the passages that match it are found on
/// this Mac and only those go to Claude, so a large briefing stays quick during a live call.
final class Briefing {
    enum Added {
        case ok(name: String, words: Int)
        case failed(name: String, why: String)
    }

    private struct Chunk {
        let source: String
        let text: String
        let counts: [String: Int]
        let length: Int
    }

    static let shared = Briefing(folder: robot.folder.appendingPathComponent("briefing"))
    static let fileTypes = ["pdf", "pptx", "docx", "doc", "rtf", "odt", "html", "htm", "txt", "md", "csv"]

    private static let maxTextLength = 2_000_000
    private static let maxPageBytes = 20_000_000
    private static let maxExcerptLength = 16_000
    private static let minWords = 20
    private static let chunkWords = 200
    private static let chunkStep = 170
    private static let stopWords: Set<String> = [
        "the", "and", "for", "are", "was", "were", "you", "your", "our", "we", "they", "them", "their", "this", "that",
        "these", "those", "with", "from", "have", "has", "had", "what", "why", "how", "when", "where", "who", "which",
        "can", "could", "would", "will", "should", "does", "did", "not", "but", "about", "into", "there", "any", "some",
        "is", "it", "its", "of", "to", "in", "on", "at", "as", "by", "be", "do", "an", "or", "if", "so", "me", "my",
    ]

    private let folder: URL
    private let lock = NSLock()
    private var chunks: [Chunk] = []
    private var documentCounts: [String: Int] = [:]
    private var averageLength = 1.0
    private var loaded = false

    init(folder: URL) {
        self.folder = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    // MARK: Sources

    var sources: [String] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "txt" }.map { $0.deletingPathExtension().lastPathComponent }.sorted()
    }

    func clear() {
        for name in sources { try? FileManager.default.removeItem(at: textFile(name)) }
        load()
    }

    private func textFile(_ name: String) -> URL { folder.appendingPathComponent(name + ".txt") }

    private func save(_ name: String, _ text: String) -> Added {
        let words = text.split(whereSeparator: \.isWhitespace).count
        guard words >= Briefing.minWords else {
            return .failed(name: name, why: robot.t("no readable text (a scanned PDF, or a page that needs a login?)", "لا يوجد نص مقروء (ملف PDF ممسوح ضوئياً، أو صفحة تتطلب تسجيل الدخول؟)"))
        }
        let safe = String(name.map { "/:\\".contains($0) ? "-" : $0 }.prefix(80))
        do {
            try String(text.prefix(Briefing.maxTextLength)).write(to: textFile(safe), atomically: true, encoding: .utf8)
            return .ok(name: safe, words: words)
        } catch {
            return .failed(name: name, why: robot.t("couldn't save it", "تعذّر حفظه"))
        }
    }

    // MARK: Adding things

    /// The supported files in `urls`, looking inside any folders.
    static func expand(_ urls: [URL]) -> [URL] {
        var found: [URL] = []
        for url in urls {
            var isFolder: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder)
            guard isFolder.boolValue else { found.append(url); continue }
            let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            while let file = walker?.nextObject() as? URL {
                if fileTypes.contains(file.pathExtension.lowercased()) { found.append(file) }
            }
        }
        return found
    }

    func add(file url: URL) -> Added {
        let name = url.deletingPathExtension().lastPathComponent
        guard Briefing.fileTypes.contains(url.pathExtension.lowercased()) else {
            return .failed(name: url.lastPathComponent, why: robot.t("this file type isn't supported", "هذا النوع من الملفات غير مدعوم"))
        }
        return save(name, Briefing.readText(url) ?? "")
    }

    /// Fetches a page once, now. Blocks, so call it off the main thread.
    func add(page address: String) -> Added {
        var text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text), let host = url.host, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return .failed(name: address, why: robot.t("that isn't a web address", "هذا ليس عنوان ويب"))
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Mozilla/5.0 (Macintosh) \(robot.name)", forHTTPHeaderField: "User-Agent")
        var body: Data?
        var contentType = ""
        let finished = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                body = data
                contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
            }
            finished.signal()
        }.resume()
        finished.wait()
        let name = (host + url.path).replacingOccurrences(of: "/", with: " ").trimmingCharacters(in: .whitespaces)
        guard let data = body, data.count <= Briefing.maxPageBytes else {
            return .failed(name: name, why: robot.t("couldn't download it", "تعذّر تنزيله"))
        }
        let isPDF = contentType.contains("pdf") || data.starts(with: Array("%PDF".utf8))
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(isPDF ? "pdf" : contentType.contains("text/plain") ? "txt" : "html")")
        defer { try? FileManager.default.removeItem(at: temp) }
        guard (try? data.write(to: temp)) != nil else { return .failed(name: name, why: robot.t("couldn't save it", "تعذّر حفظه")) }
        return save(name, Briefing.readText(temp) ?? "")
    }

    // MARK: Turning files into text

    private static func readText(_ url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "pdf": return PDFDocument(url: url)?.string
        case "pptx": return slides(url)
        case "docx", "doc", "rtf", "odt", "html", "htm":
            // -noload: never fetch images or anything else a document links to.
            return run("/usr/bin/textutil", ["-convert", "txt", "-noload", "-stdout", url.path]).flatMap { String(data: $0, encoding: .utf8) }
        default:
            return (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .isoLatin1))
        }
    }

    private static func run(_ tool: String, _ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }

    /// A .pptx is a zip of XML: one file per slide, plus speaker notes.
    private static func slides(_ url: URL) -> String? {
        guard let listing = run("/usr/bin/unzip", ["-Z1", url.path]).flatMap({ String(data: $0, encoding: .utf8) }) else { return nil }
        func numbered(_ prefix: String) -> [(Int, String)] {
            listing.split(separator: "\n").map(String.init).compactMap { member in
                guard member.hasPrefix(prefix), member.hasSuffix(".xml"), let n = Int(member.dropFirst(prefix.count).dropLast(4)) else { return nil }
                return (n, member)
            }.sorted { $0.0 < $1.0 }
        }
        var parts: [String] = []
        for (label, prefix) in [("Slide", "ppt/slides/slide"), ("Speaker notes", "ppt/notesSlides/notesSlide")] {
            for (number, member) in numbered(prefix) {
                guard let xml = run("/usr/bin/unzip", ["-p", url.path, member]).flatMap({ String(data: $0, encoding: .utf8) }) else { continue }
                let text = drawingText(xml)
                if !text.isEmpty { parts.append("\(label) \(number): \(text)") }
            }
        }
        return parts.joined(separator: "\n")
    }

    private static func drawingText(_ xml: String) -> String {
        guard let pattern = try? NSRegularExpression(pattern: "<a:t(?:\\s[^>]*)?>([^<]*)</a:t>") else { return "" }
        let range = NSRange(xml.startIndex..., in: xml)
        return pattern.matches(in: xml, range: range).compactMap { match in
            Range(match.range(at: 1), in: xml).map { String(xml[$0]) }
        }.joined(separator: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    // MARK: Finding passages

    private static func terms(_ text: String) -> [String] {
        text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).compactMap { word in
            guard word.count > 1, !stopWords.contains(word) else { return nil }
            return word.count > 3 && word.hasSuffix("s") && !word.hasSuffix("ss") ? String(word.dropLast()) : word
        }
    }

    /// Reads the saved text and rebuilds the search index. Takes a moment, so call it off the main thread.
    func load() {
        var built: [Chunk] = []
        var counts: [String: Int] = [:]
        for name in sources {
            guard let text = try? String(contentsOf: textFile(name), encoding: .utf8) else { continue }
            let words = text.split(whereSeparator: \.isWhitespace)
            for start in stride(from: 0, to: max(words.count, 1), by: Briefing.chunkStep) {
                let piece = words[start..<min(start + Briefing.chunkWords, words.count)].joined(separator: " ")
                let tokens = Briefing.terms(piece)
                guard !tokens.isEmpty else { continue }
                let chunkCounts = Dictionary(tokens.map { ($0, 1) }, uniquingKeysWith: +)
                for term in chunkCounts.keys { counts[term, default: 0] += 1 }
                built.append(Chunk(source: name, text: piece, counts: chunkCounts, length: tokens.count))
            }
        }
        lock.lock()
        chunks = built
        documentCounts = counts
        averageLength = built.isEmpty ? 1 : Double(built.reduce(0) { $0 + $1.length }) / Double(built.count)
        loaded = true
        lock.unlock()
    }

    /// The passages that best match a question (BM25 ranking), labelled by source. Empty if nothing
    /// matches. Recent conversation helps with follow-ups, but the question itself must match.
    func excerpts(question: String, context: String) -> String {
        lock.lock()
        let ready = loaded
        lock.unlock()
        if !ready { load() }
        lock.lock()
        defer { lock.unlock() }
        let asked = Set(Briefing.terms(question))
        guard !chunks.isEmpty, !asked.isEmpty else { return "" }
        var weights: [String: Double] = [:]
        for term in Briefing.terms(context.components(separatedBy: "\n").suffix(4).joined(separator: " ")) { weights[term] = 0.25 }
        for term in asked { weights[term] = 1 }

        let total = Double(chunks.count)
        var ranked: [(score: Double, chunk: Chunk)] = []
        for chunk in chunks where asked.contains(where: { chunk.counts[$0] != nil }) {
            var score = 0.0
            for (term, weight) in weights {
                guard let count = chunk.counts[term].map(Double.init) else { continue }
                let seen = Double(documentCounts[term] ?? 1)
                let rarity = log(1 + (total - seen + 0.5) / (seen + 0.5))
                score += weight * rarity * (count * 2.4) / (count + 1.4 * (0.25 + 0.75 * Double(chunk.length) / averageLength))
            }
            ranked.append((score, chunk))
        }
        ranked.sort { $0.score > $1.score }
        guard let best = ranked.first?.score, best > 0 else { return "" }

        var result: [String] = []
        var used = 0
        for (score, chunk) in ranked where score >= best * 0.3 {
            guard used + chunk.text.count <= Briefing.maxExcerptLength else { break }
            used += chunk.text.count
            // Document text can't close the tag that marks it as reference material.
            result.append("[\(chunk.source)]\n\(chunk.text.replacingOccurrences(of: "</briefing", with: "", options: .caseInsensitive))")
        }
        return result.joined(separator: "\n\n")
    }

    // MARK: Picking files

    static func pickFiles() -> [URL] {
        let panel = NSOpenPanel()
        panel.message = robot.t("Choose what \(robot.name) should know for this call", "اختر ما يجب أن يعرفه \(robot.name) لهذه المكالمة")
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = fileTypes.compactMap { UTType(filenameExtension: $0) } + [.folder]
        return panel.runModal() == .OK ? panel.urls : []
    }
}
