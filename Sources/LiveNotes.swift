import Cocoa

/// Floating window that shows the meeting transcript as it happens. It starts small next to Zolt,
/// grows taller with every line until it reaches most of the screen, then scrolls to follow the
/// newest words (unless you've scrolled up to read something).
final class LiveNotesPanel: NSObject, NSWindowDelegate {
    var onStop: (() -> Void)?
    var onOpenFile: (() -> Void)?

    private let width: CGFloat = 400
    private let headerHeight: CGFloat = 40
    private let minHeight: CGFloat = 150
    private var panel: NSPanel!
    private let status = NSTextField(labelWithString: "")
    private let button = NSButton(title: "Stop", target: nil, action: nil)
    private let scroll = NSScrollView()
    private let text = NSTextView()

    private var committed = NSMutableAttributedString()
    private var partials: [String: String] = [:]
    private var startedAt = Date()
    private var clockTimer: Timer?
    private var userSized = false
    private var finished = false
    private var lineCount = 0

    private let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    private let bodyFont = NSFont.systemFont(ofSize: 13)
    private let nameFont = NSFont.boldSystemFont(ofSize: 13)
    private let timeFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private let speakerColors = ["You": hex("#185FA5"), "Others": hex("#534AB7")]
    private let amber = hex("#BA7517")
    private var thinkingAbout: String?

    override init() {
        super.init()
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: minHeight),
                        styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.title = "Live notes"
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 280, height: 120)
        panel.delegate = self

        let content = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        content.autoresizingMask = [.width, .height]

        status.font = .systemFont(ofSize: 12, weight: .medium)
        status.textColor = .secondaryLabelColor
        status.frame = NSRect(x: 14, y: content.bounds.height - headerHeight + 11, width: width - 110, height: 18)
        status.autoresizingMask = [.width, .minYMargin]

        button.bezelStyle = .rounded
        button.controlSize = .small
        button.target = self
        button.action = #selector(buttonClicked)
        button.frame = NSRect(x: width - 92, y: content.bounds.height - headerHeight + 8, width: 80, height: 24)
        button.autoresizingMask = [.minXMargin, .minYMargin]

        scroll.frame = NSRect(x: 0, y: 0, width: width, height: content.bounds.height - headerHeight)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.textContainerInset = NSSize(width: 12, height: 8)
        text.isVerticallyResizable = true
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.frame = scroll.bounds
        scroll.documentView = text

        content.addSubview(status)
        content.addSubview(button)
        content.addSubview(scroll)
        panel.contentView = content
    }

    /// Opens a fresh, empty window beside Zolt's window.
    func begin(near anchor: NSRect) {
        committed = NSMutableAttributedString()
        partials = [:]
        thinkingAbout = nil
        lineCount = 0
        finished = false
        userSized = false
        startedAt = Date()
        button.title = "Stop"

        let screen = (NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main)?.visibleFrame ?? anchor
        var x = anchor.minX - width - 8
        if x < screen.minX { x = min(anchor.maxX + 8, screen.maxX - width) }
        let top = min(anchor.maxY, screen.maxY)
        panel.setFrame(NSRect(x: x, y: top - minHeight, width: width, height: minHeight), display: false)
        render()
        updateStatus()
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.updateStatus() }
        panel.orderFrontRegardless()
    }

    func show() { panel.orderFrontRegardless() }

    func append(who: String, text line: String, at time: Date) {
        let entry = NSMutableAttributedString()
        if committed.length > 0 { entry.append(NSAttributedString(string: "\n")) }
        entry.append(NSAttributedString(string: timeFormat.string(from: time) + "  ",
                                        attributes: [.font: timeFont, .foregroundColor: NSColor.tertiaryLabelColor]))
        entry.append(NSAttributedString(string: who + "  ",
                                        attributes: [.font: nameFont, .foregroundColor: speakerColors[who] ?? NSColor.labelColor]))
        entry.append(NSAttributedString(string: line, attributes: [.font: bodyFont, .foregroundColor: NSColor.labelColor]))
        committed.append(entry)
        partials[who] = nil
        lineCount += 1
        render()
    }

    /// Shows (or with nil, clears) a "thinking about a question" line under the transcript.
    func thinking(about question: String?) {
        thinkingAbout = question
        render()
    }

    /// Adds an answer card under the question it answers.
    func suggestion(_ answer: String, at time: Date) {
        let card = NSMutableAttributedString(string: committed.length > 0 ? "\n" : "")
        let indent = NSMutableParagraphStyle()
        indent.firstLineHeadIndent = 14
        indent.headIndent = 14
        indent.paragraphSpacing = 6
        card.append(NSAttributedString(string: "💡 Suggested answer\n",
                                       attributes: [.font: nameFont, .foregroundColor: amber, .paragraphStyle: indent]))
        card.append(NSAttributedString(string: answer,
                                       attributes: [.font: bodyFont, .foregroundColor: NSColor.labelColor,
                                                    .backgroundColor: amber.withAlphaComponent(0.12), .paragraphStyle: indent]))
        committed.append(card)
        thinkingAbout = nil
        render()
    }

    func partial(who: String, text line: String) {
        partials[who] = line.isEmpty ? nil : line
        render()
    }

    /// Switches to the "done" state once notes are saved.
    func finish(message: String) {
        finished = true
        partials = [:]
        thinkingAbout = nil
        clockTimer?.invalidate()
        status.stringValue = message
        status.textColor = .secondaryLabelColor
        button.title = "Open notes"
        render()
    }

    @objc private func buttonClicked() {
        if finished { onOpenFile?() } else { onStop?() }
    }

    private func updateStatus() {
        guard !finished else { return }
        let s = Int(Date().timeIntervalSince(startedAt))
        let elapsed = s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
                                : String(format: "%d:%02d", s / 60, s % 60)
        let dot = s % 2 == 0 ? "●" : "○"
        status.stringValue = "\(dot) Taking notes · \(elapsed) · \(lineCount) lines"
        status.textColor = hex("#E24B4A")
    }

    private func render() {
        let wasAtBottom = isAtBottom()
        let shown = NSMutableAttributedString(attributedString: committed)
        for who in ["Others", "You"] {
            guard let words = partials[who] else { continue }
            if shown.length > 0 { shown.append(NSAttributedString(string: "\n")) }
            shown.append(NSAttributedString(string: "      " + who + "  ",
                                            attributes: [.font: nameFont, .foregroundColor: (speakerColors[who] ?? .labelColor).withAlphaComponent(0.5)]))
            shown.append(NSAttributedString(string: words + " …",
                                            attributes: [.font: bodyFont, .foregroundColor: NSColor.secondaryLabelColor]))
        }
        if thinkingAbout != nil {
            if shown.length > 0 { shown.append(NSAttributedString(string: "\n")) }
            shown.append(NSAttributedString(string: "      💡 Thinking of an answer…",
                                            attributes: [.font: bodyFont, .foregroundColor: amber.withAlphaComponent(0.7)]))
        }
        if shown.length == 0 {
            shown.append(NSAttributedString(string: "Listening… words will show up here as people talk.",
                                            attributes: [.font: bodyFont, .foregroundColor: NSColor.tertiaryLabelColor]))
        }
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 6
        style.lineHeightMultiple = 1.1
        shown.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: shown.length))
        text.textStorage?.setAttributedString(shown)

        grow()
        if wasAtBottom { text.scrollToEndOfDocument(nil) }
    }

    /// Makes the window taller to fit the transcript, keeping its top edge in place,
    /// until it would leave the screen. Stops once you resize it yourself.
    private func grow() {
        guard !userSized, let lm = text.layoutManager, let tc = text.textContainer else { return }
        lm.ensureLayout(for: tc)
        let needed = lm.usedRect(for: tc).height + text.textContainerInset.height * 2 + headerHeight + 28
        let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var frame = panel.frame
        let maxHeight = min(screen.height * 0.8, frame.maxY - screen.minY)
        let target = min(max(minHeight, needed), maxHeight)
        guard target > frame.height + 1 else { return }
        frame.origin.y = frame.maxY - target
        frame.size.height = target
        panel.setFrame(frame, display: true, animate: false)
    }

    private func isAtBottom() -> Bool {
        let clip = scroll.contentView.bounds
        return clip.maxY >= text.frame.height - 30
    }

    func windowWillStartLiveResize(_ notification: Notification) { userSized = true }
}
