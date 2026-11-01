import AVFoundation
import CoreAudio
import Foundation

// MARK: - Core Audio helpers

/// A process Core Audio knows about, with whether it's using the mic or speakers right now.
struct AudioProcess {
    let object: AudioObjectID
    let pid: pid_t
    let bundleID: String
    let input: Bool
    let output: Bool

    /// The meeting app this process belongs to, if any.
    var meetingApp: MeetingApp? {
        let id = bundleID.lowercased()
        return MeetingApp.all.first { app in app.prefixes.contains { id.hasPrefix($0) } }
    }
}

/// Apps Bolt watches for calls. Google Meet runs in a browser, so any browser using the mic counts.
struct MeetingApp: Equatable {
    let name: String
    let prefixes: [String]

    static let all = [
        MeetingApp(name: "Teams", prefixes: ["com.microsoft.teams"]),
        MeetingApp(name: "Zoom", prefixes: ["us.zoom."]),
        MeetingApp(name: "Google Meet", prefixes: ["com.google.chrome", "com.apple.safari", "com.apple.webkit",
                                                   "com.microsoft.edgemac", "company.thebrowser.", "com.brave.browser",
                                                   "org.mozilla.firefox"]),
    ]
}

private func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                               mElement: kAudioObjectPropertyElementMain)
}

private func readValue<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ initial: T) -> T? {
    var addr = address(selector)
    var value = initial
    var size = UInt32(MemoryLayout<T>.size)
    let status = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(object, &addr, 0, nil, &size, $0) }
    return status == noErr ? value : nil
}

private func readString(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    var addr = address(selector)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    let status = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(object, &addr, 0, nil, &size, $0) }
    guard status == noErr, let value else { return nil }
    return value.takeRetainedValue() as String
}

func audioProcesses() -> [AudioProcess] {
    let system = AudioObjectID(kAudioObjectSystemObject)
    var addr = address(kAudioHardwarePropertyProcessObjectList)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
    return ids.map { id in
        AudioProcess(object: id,
                     pid: readValue(id, kAudioProcessPropertyPID, pid_t(0)) ?? 0,
                     bundleID: readString(id, kAudioProcessPropertyBundleID) ?? "",
                     input: (readValue(id, kAudioProcessPropertyIsRunningInput, UInt32(0)) ?? 0) != 0,
                     output: (readValue(id, kAudioProcessPropertyIsRunningOutput, UInt32(0)) ?? 0) != 0)
    }
}

/// Peak level of a float buffer, used to notice when captured audio is pure silence.
func peak(_ buffer: AVAudioPCMBuffer) -> Float {
    guard let data = buffer.floatChannelData else { return 1 } // Non-float: assume there's sound.
    let channels = Int(buffer.format.channelCount), frames = Int(buffer.frameLength)
    var p: Float = 0
    if buffer.format.isInterleaved {
        // All channels are packed into the first buffer.
        for i in 0..<(frames * channels) { p = max(p, abs(data[0][i])) }
    } else {
        for ch in 0..<channels {
            for i in 0..<frames { p = max(p, abs(data[ch][i])) }
        }
    }
    return p
}

// MARK: - System audio (what you hear from Teams)

/// Captures the sound other apps play, using a Core Audio process tap (needs the
/// "Screen & System Audio Recording" permission). Taps the given processes, or, when the
/// list is empty, everything except Bolt itself.
final class SystemAudioCapture {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "bolt.systemaudio")

    func start(processes: [AudioObjectID], onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
        let desc: CATapDescription
        if processes.isEmpty {
            let me = audioProcesses().filter { $0.pid == getpid() }.map(\.object)
            desc = CATapDescription(stereoGlobalTapButExcludeProcesses: me)
        } else {
            desc = CATapDescription(stereoMixdownOfProcesses: processes)
        }
        desc.uuid = UUID()
        desc.muteBehavior = .unmuted
        desc.isPrivate = true
        try check(AudioHardwareCreateProcessTap(desc, &tapID), "create tap")

        guard var asbd = readValue(tapID, kAudioTapPropertyFormat, AudioStreamBasicDescription()),
              let format = AVAudioFormat(streamDescription: &asbd) else {
            throw NSError(domain: "Bolt", code: 1, userInfo: [NSLocalizedDescriptionKey: "Couldn't read the tap's audio format."])
        }

        let outputDevice = readValue(AudioObjectID(kAudioObjectSystemObject),
                                     kAudioHardwarePropertyDefaultSystemOutputDevice, AudioObjectID(0)) ?? 0
        let outputUID = readString(outputDevice, kAudioDevicePropertyDeviceUID) ?? ""
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Bolt Notes",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true,
                                               kAudioSubTapUIDKey: desc.uuid.uuidString]],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &deviceID), "create device")

        try check(AudioDeviceCreateIOProcIDWithBlock(&procID, deviceID, queue) { _, input, _, _, _ in
            if let buf = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: input, deallocator: nil) {
                onBuffer(buf)
            }
        }, "create IO proc")
        try check(AudioDeviceStart(deviceID, procID), "start device")
        log("system audio tap started (\(processes.isEmpty ? "all apps" : "\(processes.count) meeting processes"), \(format))")
    }

    func stop() {
        if deviceID != kAudioObjectUnknown {
            AudioDeviceStop(deviceID, procID)
            if let procID { AudioDeviceDestroyIOProcID(deviceID, procID) }
            AudioHardwareDestroyAggregateDevice(deviceID)
        }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        procID = nil
        deviceID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    private func check(_ status: OSStatus, _ what: String) throws {
        guard status == noErr else {
            throw NSError(domain: "Bolt", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Couldn't \(what) (\(status))."])
        }
    }
}

// MARK: - Meeting detection

/// Polls Core Audio for a meeting app (Teams, Zoom, or a browser for Google Meet) using the mic.
/// Reports a meeting start once per meeting, and an end when that app has used neither the mic nor
/// the speakers for `endAfter` seconds.
final class MeetingWatcher {
    var onStart: ((MeetingApp) -> Void)?
    var onEnd: (() -> Void)?
    var enabled = true
    let endAfter: TimeInterval = 50

    private(set) var app: MeetingApp?
    var inMeeting: Bool { app != nil }
    private var lastActive = Date.distantPast
    private var lastInputUsers: Set<String> = []
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.poll() }
    }

    /// The audio processes of the current meeting app (empty when there's no meeting).
    func meetingProcesses() -> [AudioObjectID] {
        guard let app else { return [] }
        return audioProcesses().filter { $0.meetingApp == app }.map(\.object)
    }

    private func poll() {
        let procs = audioProcesses()
        // Log who's using the mic whenever that changes, to learn which processes Teams uses.
        let users = Set(procs.filter(\.input).map { $0.bundleID.isEmpty ? "pid \($0.pid)" : $0.bundleID })
        if users != lastInputUsers {
            log("mic in use by: \(users.sorted().joined(separator: ", "))")
            lastInputUsers = users
        }

        if let app {
            let mine = procs.filter { $0.meetingApp == app }
            if mine.contains(where: { $0.input || $0.output }) { lastActive = Date() }
            if Date().timeIntervalSince(lastActive) > endAfter {
                self.app = nil
                log("\(app.name) meeting ended")
                onEnd?()
            }
        } else if let found = procs.first(where: { $0.input && $0.meetingApp != nil })?.meetingApp {
            app = found
            lastActive = Date()
            log("\(found.name) meeting detected")
            if enabled { onStart?(found) }
        }
    }
}

// MARK: - Questions

/// A cheap first check for whether a transcript line asks something. Claude makes the real call
/// (and skips small talk), so this only needs to avoid sending every line.
func looksLikeQuestion(_ text: String) -> Bool {
    let words = text.lowercased().components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
    guard words.count >= 4 else { return false }
    if text.contains("?") { return true }
    let starters: Set<String> = ["what", "why", "how", "when", "where", "who", "which", "can", "could", "would",
                                 "will", "do", "does", "did", "is", "are", "should", "have", "has"]
    if starters.contains(words[0]) { return true }
    let phrases = ["any thoughts", "what do you think", "can you", "could you", "do you know", "any idea",
                   "your take", "what about", "how about", "thoughts on"]
    let lower = text.lowercased()
    return phrases.contains { lower.contains($0) }
}

// MARK: - Note taker

/// Records your mic ("You") and Teams' sound ("Others"), transcribes both live into a Markdown
/// file in ~/Bolt Meeting Notes, and adds a Claude summary when you stop.
final class NoteTaker {
    static let folder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Bolt Meeting Notes")

    var onStatus: ((String) -> Void)?
    /// A finalized line (speaker, text, time), for the live notes window.
    var onCommit: ((String, String, Date) -> Void)?
    /// Words still being spoken (speaker, text; empty clears).
    var onPartial: ((String, String) -> Void)?
    private(set) var active = false
    private(set) var startedAt = Date()
    private(set) var file: URL?

    private let micEngine = AVAudioEngine()
    private let system = SystemAudioCapture()
    private let you = StreamTranscriber()
    private let others = StreamTranscriber()
    private var header = ""
    private var lines: [String] = []
    private var lastSound = Date()
    private var warnedSilence = false
    private var silenceTimer: Timer?
    private let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    /// The last few transcript lines, as context for answering a question.
    func recentTranscript(_ count: Int = 30) -> String {
        lines.suffix(count).joined(separator: "\n")
    }

    /// Starts recording. `teams` are the meeting app's audio processes; empty means all system audio.
    func start(title: String, teams: [AudioObjectID]) {
        guard !active else { return }
        active = true
        lines = []
        warnedSilence = false
        startedAt = Date()
        lastSound = Date()

        try? FileManager.default.createDirectory(at: NoteTaker.folder, withIntermediateDirectories: true)
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd HH.mm"
        file = NoteTaker.folder.appendingPathComponent("\(stamp.string(from: startedAt)) \(title).md")
        header = "# \(title) — \(DateFormatter.localizedString(from: startedAt, dateStyle: .full, timeStyle: .short))\n"
        writeFile(summary: "_Taking notes…_")

        you.onLine = { [weak self] text in DispatchQueue.main.async { self?.add("You", text) } }
        others.onLine = { [weak self] text in DispatchQueue.main.async { self?.add("Others", text) } }
        you.onPartial = { [weak self] text in DispatchQueue.main.async { self?.onPartial?("You", text) } }
        others.onPartial = { [weak self] text in DispatchQueue.main.async { self?.onPartial?("Others", text) } }

        Task { @MainActor in
            do {
                try await you.start()
                try await others.start()
            } catch {
                log("note taker transcriber start failed: \(error)")
                onStatus?("I couldn't start my note-taking ears: \(error.localizedDescription)")
                stopCapture()
                active = false
                return
            }
            startMic()
            do {
                try system.start(processes: teams) { [weak self] buf in
                    guard let self else { return }
                    if peak(buf) > 0.0005 { self.lastSound = Date() }
                    self.others.feed(buf)
                }
            } catch {
                log("system audio capture failed: \(error)")
                onStatus?("I can only hear your side: \(error.localizedDescription) Allow Bolt in Privacy & Security → Screen & System Audio Recording.")
            }
            silenceTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.checkSilence() }
        }
    }

    private func startMic() {
        let input = micEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            onStatus?("I can't reach the microphone, so I'll only note what the others say.")
            return
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buf, _ in self?.you.feed(buf) }
        do { try micEngine.start() } catch {
            log("note taker mic failed: \(error)")
        }
    }

    private func checkSilence() {
        guard active, !warnedSilence, Date().timeIntervalSince(lastSound) > 25 else { return }
        warnedSilence = true
        onStatus?("I'm not hearing any sound from the call yet. If others are talking, allow Bolt in System Settings → Privacy & Security → Screen & System Audio Recording.")
    }

    // Without headphones the mic also hears the call, so the same words arrive as both "You" and
    // "Others". "You" lines are held briefly and dropped if they match something Others said.
    private var recentOthers: [(Date, Set<String>)] = []
    private var pendingYou: [(Date, String, Set<String>)] = []
    private var flushTimer: Timer?

    private func words(_ text: String) -> Set<String> {
        Set(text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
    }

    private func isEcho(_ a: Set<String>, _ b: Set<String>) -> Bool {
        let smaller = min(a.count, b.count)
        guard smaller > 0 else { return false }
        return Double(a.intersection(b).count) / Double(smaller) >= 0.6
    }

    private func add(_ who: String, _ text: String) {
        guard active || file != nil else { return }
        let now = Date()
        let w = words(text)
        recentOthers.removeAll { now.timeIntervalSince($0.0) > 20 }
        if who == "Others" {
            recentOthers.append((now, w))
            let before = pendingYou.count
            pendingYou.removeAll { isEcho($0.2, w) }
            if pendingYou.count != before { log("dropped \(before - pendingYou.count) echoed line(s)") }
            commit(who, text, at: now)
        } else if recentOthers.contains(where: { isEcho($0.1, w) }) {
            log("dropped an echoed line")
            onPartial?("You", "")
        } else {
            pendingYou.append((now, text, w))
            if flushTimer == nil {
                flushTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.flushYou(force: false) }
            }
        }
    }

    private func flushYou(force: Bool) {
        let now = Date()
        while let first = pendingYou.first, force || now.timeIntervalSince(first.0) > 6 {
            pendingYou.removeFirst()
            commit("You", first.1, at: first.0)
        }
    }

    private func commit(_ who: String, _ text: String, at time: Date) {
        lines.append("**[\(clock.string(from: time))] \(who):** \(text)")
        writeFile(summary: "_Taking notes…_")
        onCommit?(who, text, time)
    }

    private func writeFile(summary: String) {
        guard let file else { return }
        let body = header + "\n" + summary + "\n\n## Transcript\n\n" + (lines.isEmpty ? "_Nothing heard yet._" : lines.joined(separator: "\n\n")) + "\n"
        try? body.write(to: file, atomically: true, encoding: .utf8)
    }

    private func stopCapture() {
        silenceTimer?.invalidate()
        micEngine.stop()
        micEngine.inputNode.removeTap(onBus: 0)
        system.stop()
    }

    /// Stops recording, waits for the last words, and writes the summary. `done` gets a short
    /// message for the bubble.
    func stop(brain: Brain, done: @escaping (String) -> Void) {
        guard active else { return }
        active = false
        stopCapture()
        Task { @MainActor in
            await you.finish()
            await others.finish()
            flushTimer?.invalidate()
            flushTimer = nil
            flushYou(force: true)
            recentOthers = []
            guard !lines.isEmpty else {
                writeFile(summary: "_No speech was heard._")
                done("I didn't hear anything to take notes on.")
                return
            }
            writeFile(summary: "_Writing summary…_")
            let transcript = lines.joined(separator: "\n")
            brain.summarize(transcript) { [weak self] summary in
                guard let self else { return }
                if let summary {
                    self.writeFile(summary: summary)
                    let tldr = summary.components(separatedBy: "\n").first { $0.hasPrefix("TL;DR") } ?? ""
                    done("Notes saved! \(tldr) Click here to open them.")
                } else {
                    self.writeFile(summary: "_The summary couldn't be written; the full transcript is below._")
                    done("I saved the transcript, but couldn't write the summary. Click here to open it.")
                }
            }
        }
    }
}
