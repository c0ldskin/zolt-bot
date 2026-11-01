import AVFoundation
import Speech

/// Long-form, on-device speech-to-text (macOS 26 SpeechAnalyzer) fed with live audio buffers
/// from any source. Finalized phrases arrive through `onLine` (on a background thread).
final class StreamTranscriber {
    let locale = Locale(identifier: "en-US")
    var onLine: ((String) -> Void)?
    /// In-progress words before a phrase is finalized. Set before `start()` to receive them.
    var onPartial: ((String) -> Void)?

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var format: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    /// Downloads the speech model if needed and starts analysing.
    func start() async throws {
        let t = SpeechTranscriber(locale: locale, transcriptionOptions: [],
                                  reportingOptions: onPartial == nil ? [] : [.volatileResults], attributeOptions: [])
        if let install = try await AssetInventory.assetInstallationRequest(supporting: [t]) {
            log("downloading speech model for \(locale.identifier)")
            try await install.downloadAndInstall()
        }
        let a = SpeechAnalyzer(modules: [t])
        format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [t])
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        input = continuation
        transcriber = t
        analyzer = a

        resultsTask = Task { [weak self] in
            do {
                for try await result in t.results {
                    let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !result.isFinal {
                        self?.onPartial?(text)
                    } else if !text.isEmpty {
                        self?.onLine?(text)
                    }
                }
            } catch {
                log("transcriber results error: \(error)")
            }
        }
        try await a.start(inputSequence: stream)
    }

    /// Converts a buffer to the analyser's format and queues it. Call from one thread at a time.
    func feed(_ buffer: AVAudioPCMBuffer) {
        guard let target = format, let input, buffer.frameLength > 0 else { return }
        if converter == nil || converter!.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: target)
        }
        guard let converter else { return }
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * target.sampleRate / buffer.format.sampleRate) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var supplied = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        if out.frameLength > 0 { input.yield(AnalyzerInput(buffer: out)) }
    }

    /// Flushes remaining audio so the last words are transcribed, then stops.
    func finish() async {
        input?.finish()
        input = nil
        do { try await analyzer?.finalizeAndFinishThroughEndOfInput() } catch {
            log("transcriber finish error: \(error)")
        }
        await resultsTask?.value
        analyzer = nil
        transcriber = nil
    }
}

/// `Bolt --transcribe-file <path>`: runs a file through the same live pipeline and prints the text.
func runTranscribeFile(_ path: String) -> Never {
    let done = DispatchSemaphore(value: 0)
    Task {
        do {
            let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
            let t = StreamTranscriber()
            t.onLine = { print("LINE: \($0)") }
            t.onPartial = { print("partial: \($0)") }
            try await t.start()
            let chunk: AVAudioFrameCount = 4096
            while file.framePosition < file.length {
                guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunk) else { break }
                try file.read(into: buf, frameCount: chunk)
                t.feed(buf)
            }
            await t.finish()
        } catch {
            print("ERROR: \(error)")
        }
        done.signal()
    }
    done.wait()
    exit(0)
}
