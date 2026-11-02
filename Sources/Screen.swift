import Cocoa
import ScreenCaptureKit

/// One-off screenshots so Zolt can answer questions about what's on screen. Nothing is captured
/// unless the user asks; Zolt's own windows are left out of the picture.
enum Screen {
    static let file = robot.folder.appendingPathComponent("screen.png")

    /// Whether a request sounds like it's about what's on screen.
    static func wantsLook(_ text: String) -> Bool {
        let t = text.lowercased()
        return ["screen", "look at", "looking at", "see this", "this page", "this window"].contains { t.contains($0) }
    }

    /// Captures the display under the mouse pointer to `file`. Calls back on the main thread with
    /// the file, or with a message explaining what went wrong.
    static func capture(done: @escaping (Result<URL, Error>) -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                let mouse = NSEvent.mouseLocation
                let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
                let id = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                guard let display = content.displays.first(where: { $0.displayID == id }) ?? content.displays.first else {
                    throw message(robot.t("I couldn't find a screen to look at.", "لم أجد شاشة أنظر إليها."))
                }
                let mine = content.windows.filter { $0.owningApplication?.processID == getpid() }
                let filter = SCContentFilter(display: display, excludingWindows: mine)
                let config = SCStreamConfiguration()
                let scale = min(2.0, 2000.0 / Double(display.width))
                config.width = Int(Double(display.width) * scale)
                config.height = Int(Double(display.height) * scale)
                config.showsCursor = false
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                    throw message(robot.t("I took the screenshot but couldn't save it.", "التقطت الصورة لكن تعذّر حفظها."))
                }
                try png.write(to: file)
                log("screenshot saved (\(config.width)x\(config.height))")
                await MainActor.run { done(.success(file)) }
            } catch {
                log("screenshot failed: \(error)")
                if (error as NSError).domain != "\(robot.name)" {
                    // Asks macOS to show its permission prompt (or point at the setting) for this build.
                    await MainActor.run { _ = CGRequestScreenCaptureAccess() }
                }
                let friendly = (error as NSError).domain == "\(robot.name)" ? error
                    : message(robot.t("macOS blocked me from seeing your screen. In System Settings → Privacy & Security → Screen & System Audio Recording, remove \(robot.name) with the − button, add it back with +, then quit and reopen me.", "منعني macOS من رؤية شاشتك. في إعدادات النظام ← الخصوصية والأمان ← تسجيل الشاشة وصوت النظام، احذف \(robot.name) بزر −، ثم أضفه مرة أخرى بزر +، ثم أغلقني وافتحني من جديد."))
                await MainActor.run { done(.failure(friendly)) }
            }
        }
    }

    private static func message(_ text: String) -> NSError {
        NSError(domain: "\(robot.name)", code: 0, userInfo: [NSLocalizedDescriptionKey: text])
    }
}
