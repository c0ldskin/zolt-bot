import Cocoa
import ImageIO
import UniformTypeIdentifiers

// Renders the README artwork (banner, animated hero, mood tiles) straight from Zolt's own sprite
// code, so the pictures always match the app. Run: Zolt --render-art <folder>

// MARK: Pixel font (5×7)

private let glyphs: [Character: [String]] = [
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
    "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
    "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
    "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
    ".": [".....", ".....", ".....", ".....", ".....", ".....", "..#.."],
    ",": [".....", ".....", ".....", ".....", ".....", "..#..", ".#..."],
    "'": ["..#..", "..#..", ".....", ".....", ".....", ".....", "....."],
    "-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
    ":": [".....", "..#..", ".....", ".....", ".....", "..#..", "....."],
    "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
    "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
    "·": [".....", ".....", ".....", "..#..", ".....", ".....", "....."],
    "&": [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"],
    " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
]

// MARK: Arabic pixel text

// The 5×7 font above only has Latin letters. Arabic needs joined, shaped letters, so it's drawn by
// rendering the text small with a geometric Kufi font and antialiasing off, then drawing each pixel
// as a big square, which gives real pixel-art Arabic with correct shaping and right-to-left order.

private func isArabic(_ s: String) -> Bool {
    s.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) || (0xFE70...0xFEFF).contains($0.value) }
}

/// A 1-bit bitmap of the text, trimmed to its inked rows: (width, height, bits row by row from the top).
private func arabicBits(_ s: String, fontSize: CGFloat) -> (w: Int, h: Int, bits: [Bool]) {
    let font = NSFont(name: "KufiStandardGK", size: fontSize) ?? NSFont(name: "GeezaPro-Bold", size: fontSize)!
    let a = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: NSColor.black])
    let size = a.size()
    let w = Int(ceil(size.width)) + 2, h = Int(ceil(size.height)) + 2
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return (0, 0, []) }
    ctx.setShouldAntialias(false)
    ctx.setAllowsFontSmoothing(false)
    let previous = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    a.draw(at: NSPoint(x: 1, y: 1))
    NSGraphicsContext.current = previous
    let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
    // Bitmap rows run bottom to top; flip to top-down and drop empty rows.
    var rows: [[Bool]] = []
    for y in (0..<h).reversed() {
        let row = (0..<w).map { p[((h - 1 - y) * w + $0) * 4 + 3] > 127 }
        rows.append(row)
    }
    while let first = rows.first, !first.contains(true) { rows.removeFirst() }
    while let last = rows.last, !last.contains(true) { rows.removeLast() }
    return (w, rows.count, rows.flatMap { $0 })
}

/// Arabic glyphs are taller than the 5×7 Latin ones, so callers pass a smaller `px` for Arabic.
private func arabicCell(_ px: CGFloat) -> CGFloat { max(1, px.rounded()) }

/// Draws Arabic pixel text with its top-left at (x, y). `color` gets a row index scaled to 0...6.
private func arabicText(_ s: String, x: CGFloat, y: CGFloat, fontSize: CGFloat = 14, cell: CGFloat,
                        shadow: NSColor?, color: (Int) -> NSColor) {
    let (w, h, bits) = arabicBits(s, fontSize: fontSize)
    guard h > 0 else { return }
    for pass in shadow == nil ? [1] : [0, 1] {
        let off: CGFloat = pass == 0 ? max(2, (cell / 2).rounded()) : 0
        for r in 0..<h {
            (pass == 0 ? shadow! : color(r * 7 / h)).setFill()
            for c in 0..<w where bits[r * w + c] {
                NSRect(x: x + CGFloat(c) * cell + off, y: y + CGFloat(r) * cell + off, width: cell, height: cell).fill()
            }
        }
    }
}

private func arabicSize(_ s: String, fontSize: CGFloat = 14, cell: CGFloat) -> CGSize {
    let (w, h, _) = arabicBits(s, fontSize: fontSize)
    return CGSize(width: CGFloat(w) * cell, height: CGFloat(h) * cell)
}

// MARK: Pixel text (either script)

private func textWidth(_ s: String, _ px: CGFloat) -> CGFloat {
    isArabic(s) ? arabicSize(s, cell: arabicCell(px)).width : CGFloat(s.count) * 6 * px - px
}

/// Height of one line of text at this scale.
private func textHeight(_ s: String, _ px: CGFloat) -> CGFloat {
    isArabic(s) ? arabicSize(s, cell: arabicCell(px)).height : 7 * px
}

/// Draws pixel text with its top-left at (x, y). `color` gets the glyph row, for stripey fills.
private func pixelText(_ s: String, x: CGFloat, y: CGFloat, px: CGFloat, shadow: NSColor? = nil,
                       color: (Int) -> NSColor) {
    if isArabic(s) {
        arabicText(s, x: x, y: y, cell: arabicCell(px), shadow: shadow, color: color)
        return
    }
    for pass in shadow == nil ? [1] : [0, 1] {
        var cx = x
        for ch in s.uppercased() {
            let g = glyphs[ch] ?? glyphs["?"]!
            for (r, row) in g.enumerated() {
                (pass == 0 ? shadow! : color(r)).setFill()
                for (c, bit) in row.enumerated() where bit == "#" {
                    let off: CGFloat = pass == 0 ? max(2, (px / 3).rounded()) : 0
                    NSRect(x: cx + CGFloat(c) * px + off, y: y + CGFloat(r) * px + off, width: px, height: px).fill()
                }
            }
            cx += 6 * px
        }
    }
}

private func pixelText(_ s: String, x: CGFloat, y: CGFloat, px: CGFloat, color: NSColor, shadow: NSColor? = nil) {
    pixelText(s, x: x, y: y, px: px, shadow: shadow) { _ in color }
}

// MARK: Canvas

private func canvas(_ w: Int, _ h: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(h))
    ctx.scaleBy(x: 1, y: -1)
    ctx.setShouldAntialias(false)
    ctx.interpolationQuality = .none
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    return ctx
}

private func drawSprite(_ v: SpriteView, _ ctx: CGContext, x: CGFloat, y: CGFloat, k: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: x, y: y)
    ctx.scaleBy(x: k, y: k)
    v.draw(v.bounds)
    ctx.restoreGState()
}

private func writePNG(_ ctx: CGContext, _ url: URL) {
    let data = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    try? data.write(to: url)
    print("wrote \(url.lastPathComponent)")
}

private func writeGIF(_ frames: [CGImage], delay: Double, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
    CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    let props = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay,
                                                 kCGImagePropertyGIFUnclampedDelayTime: delay]] as CFDictionary
    for f in frames { CGImageDestinationAddImage(dest, f, props) }
    CGImageDestinationFinalize(dest)
    print("wrote \(url.lastPathComponent) (\(frames.count) frames)")
}

// MARK: Synthwave scenery

private let pink = hex("#FF3EA5"), cyan = hex("#29E0FF"), night = hex("#0B0B2B"), ground = hex("#14052B")

/// Stepped sky, stars, an optional striped sun, and a perspective grid floor that scrolls with `phase`.
private func scenery(_ ctx: CGContext, w: CGFloat, h: CGFloat, horizon: CGFloat,
                     sun: (CGFloat, CGFloat)?, phase: CGFloat, twinkle: Int, noStars: CGRect = .zero) {
    let sky = ["#0B0B2B", "#140C3A", "#1E0E48", "#2A1056", "#381262", "#48136B", "#5A1470", "#6E1673"]
    let band = horizon / CGFloat(sky.count)
    for (i, c) in sky.enumerated() {
        hex(c).setFill()
        NSRect(x: 0, y: (CGFloat(i) * band).rounded(), width: w, height: band.rounded() + 1).fill()
    }

    var seed: UInt32 = 7
    func rand() -> CGFloat { seed = seed &* 1_103_515_245 &+ 12345; return CGFloat((seed >> 16) & 0x7FFF) / 32767 }
    let starColors = [NSColor.white, cyan, hex("#FAC775")]
    for i in 0..<Int(w / 9) {
        let x = (rand() * w).rounded(), y = (rand() * (horizon - 30)).rounded()
        let size: CGFloat = rand() > 0.85 ? 4 : 2
        let on = (i + twinkle / 3) % 7 != 0
        guard on, !noStars.contains(CGPoint(x: x, y: y)) else { continue }
        starColors[i % 3].withAlphaComponent(rand() > 0.5 ? 1 : 0.55).setFill()
        NSRect(x: x, y: y, width: size, height: size).fill()
    }

    if let (cx, r) = sun {
        let sunBands = ["#FFE45C", "#FFC23D", "#FF9A3D", "#FF6E5A", "#FF4F86", "#E83A9E"]
        let top = horizon - r
        let step = r / CGFloat(sunBands.count)
        var y = top
        while y < horizon {
            let t = (y - top) / r
            hex(sunBands[min(sunBands.count - 1, Int(t * CGFloat(sunBands.count)))]).setFill()
            let dy = horizon - y
            let half = sqrt(max(0, r * r - dy * dy))
            // Stripes cut through the lower half, getting thicker toward the horizon.
            let gap = t > 0.45 && Int((y - top) / (step / 2)) % 3 == 0
            if !gap { NSRect(x: (cx - half).rounded(), y: y, width: (half * 2).rounded(), height: 4).fill() }
            y += 4
        }
    }

    ground.setFill()
    NSRect(x: 0, y: horizon, width: w, height: h - horizon).fill()
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: horizon, width: w, height: h - horizon))
    ctx.setStrokeColor(pink.withAlphaComponent(0.85).cgColor)
    ctx.setLineWidth(2)
    let vp = w / 2
    for i in -14...14 {
        ctx.move(to: CGPoint(x: vp + CGFloat(i) * 18, y: horizon))
        ctx.addLine(to: CGPoint(x: vp + CGFloat(i) * 150, y: h))
    }
    for j in 0..<10 {
        let t = (CGFloat(j) + phase) / 10
        let y = (horizon + (h - horizon) * t * t).rounded()
        ctx.move(to: CGPoint(x: 0, y: y))
        ctx.addLine(to: CGPoint(x: w, y: y))
    }
    ctx.strokePath()
    ctx.restoreGState()
    hex("#FF7AC6").setFill()
    NSRect(x: 0, y: horizon - 2, width: w, height: 4).fill()
}

/// Chunky pixel speech bubble with a tail pointing left, sized for `lines` at text scale `px`.
private func bubble(_ lines: [String], x: CGFloat, y: CGFloat, px: CGFloat, reveal: Int) {
    let u: CGFloat = 4
    let pad = px * 4
    let w = (lines.map { textWidth($0, px) }.max() ?? 0) + pad * 2
    let lineHeight = (lines.map { textHeight($0, px) }.max() ?? 7 * px) + px * 3
    let h = CGFloat(lines.count) * lineHeight - px * 3 + pad * 2
    let ink = hex("#0C447C")
    ink.setFill()
    NSRect(x: x + u, y: y, width: w - 2 * u, height: h).fill()
    NSRect(x: x, y: y + u, width: w, height: h - 2 * u).fill()
    for i in 0..<4 { NSRect(x: x - CGFloat(i + 1) * u, y: y + h / 2 + CGFloat(i) * u, width: u, height: u * CGFloat(4 - i)).fill() }
    NSColor.white.setFill()
    NSRect(x: x + u, y: y + u, width: w - 2 * u, height: h - 2 * u).fill()
    for i in 0..<3 { NSRect(x: x - CGFloat(i) * u, y: y + h / 2 + CGFloat(i + 1) * u, width: u, height: u * CGFloat(2 - i)).fill() }
    var left = reveal
    for (i, line) in lines.enumerated() {
        let shown = String(line.prefix(max(0, left)))
        left -= line.count
        guard !shown.isEmpty else { continue }
        // Arabic is right-aligned, so it types out from the right like it's written.
        let tx = isArabic(line) ? x + w - pad - textWidth(shown, px) : x + pad
        pixelText(shown, x: tx, y: y + pad + CGFloat(i) * lineHeight, px: px, color: ink)
    }
}

// MARK: Zolt in different moods

private struct Scene {
    let caption: String
    let lines: [String]
    let color: NSColor
    let setup: (SpriteView) -> Void
}

private let scenes: [Scene] = robot.arabic ? [
    Scene(caption: "مرحبا!", lines: ["أهلاً، أنا زميل!", "اضغط عليّ وتكلّم"], color: cyan) { _ in },
    Scene(caption: "أسمعك", lines: ["«ذكّرني أتصل", "بأمي الساعة 6»"], color: hex("#2BD67B")) { $0.mood = .listening },
    Scene(caption: "أفكّر...", lines: ["لحظة وحدة،", "أشوف لك..."], color: hex("#B69CFF")) { $0.mood = .thinking },
    Scene(caption: "أتكلّم", lines: ["تم! وأسألك دائماً", "قبل أي إجراء"], color: hex("#FFB000")) { $0.mood = .talking },
    Scene(caption: "فكرة!", lines: ["وش رأيك باستراحة", "قهوة 5 دقايق؟"], color: hex("#FFE45C")) { $0.showIdea() },
    Scene(caption: "اجتماع", lines: ["أدوّن الملاحظات", "وألتقط الأسئلة"], color: hex("#FF6B3D")) { $0.takingNotes = true },
    Scene(caption: "قيلولة", lines: ["نايم لين", "تحتاجني"], color: hex("#7FA8FF")) { $0.asleep = true },
] : [
    Scene(caption: "HELLO!", lines: ["HI, I'M \(robot.name.uppercased())!", "CLICK ME & TALK."], color: cyan) { _ in },
    Scene(caption: "LISTENING", lines: ["\"REMIND ME TO", "CALL MOM AT 6\""], color: hex("#2BD67B")) { $0.mood = .listening },
    Scene(caption: "THINKING", lines: ["HMM... ONE", "SECOND..."], color: hex("#B69CFF")) { $0.mood = .thinking },
    Scene(caption: "TALKING", lines: ["DONE! I'LL ASK", "BEFORE I ACT."], color: hex("#FFB000")) { $0.mood = .talking },
    Scene(caption: "IDEA!", lines: ["TAKE A 5 MIN", "DANCE BREAK?"], color: hex("#FFE45C")) { $0.showIdea() },
    Scene(caption: "MEETING", lines: ["TAKING NOTES", "& SPOTTING Q'S"], color: hex("#FF6B3D")) { $0.takingNotes = true },
    Scene(caption: "ZZZ...", lines: ["NAPPING TILL", "YOU NEED ME."], color: hex("#7FA8FF")) { $0.asleep = true },
]

private func sprite(_ scene: Scene, tick: Int) -> SpriteView {
    let v = SpriteView(frame: NSRect(x: 0, y: 0, width: 150, height: 112))
    v.tick = tick
    scene.setup(v)
    return v
}

// MARK: Pieces

private func renderBanner(_ dir: URL) {
    let w: CGFloat = 1280, h: CGFloat = 640, horizon: CGFloat = 470
    let ctx = canvas(Int(w), Int(h))
    let stripes = ["#FFE45C", "#FFE45C", "#FFC23D", "#FF9A3D", "#FF9A3D", "#FF6E5A", "#FF4F86"]
    let k: CGFloat = 20

    if robot.arabic {
        // Mirrored for right-to-left: the character on the left, Arabic text right-aligned.
        scenery(ctx, w: w, h: h, horizon: horizon, sun: (330, 230), phase: 0.35, twinkle: 0,
                noStars: CGRect(x: 520, y: 60, width: 700, height: 380))
        drawRobot(at: CGPoint(x: 330 - 7 * k, y: horizon - CGFloat(robot.grid.count) * k + 6), scale: k, eyes: .bright)
        let right: CGFloat = 1196
        let shade = hex("#3A0E5E")
        func line(_ s: String, y: CGFloat, fontSize: CGFloat, cell: CGFloat, shadow: NSColor, color: @escaping (Int) -> NSColor) {
            let size = arabicSize(s, fontSize: fontSize, cell: cell)
            arabicText(s, x: right - size.width, y: y, fontSize: fontSize, cell: cell, shadow: shadow, color: color)
        }
        line("زميل", y: 70, fontSize: 30, cell: 7, shadow: pink) { hex(stripes[$0]) }
        line("رفيقك البكسلي الصغير", y: 300, fontSize: 14, cell: 4, shadow: shade) { _ in .white }
        line("لأجهزة ماك · يتكلّم العربية", y: 372, fontSize: 14, cell: 3, shadow: shade) { _ in cyan }
        line("يسمع · يتكلّم · يدوّن · عنده أفكار", y: 420, fontSize: 14, cell: 3, shadow: shade) { _ in hex("#FFB000") }
        writePNG(ctx, dir.appendingPathComponent("banner.png"))
        return
    }

    scenery(ctx, w: w, h: h, horizon: horizon, sun: (950, 230), phase: 0.35, twinkle: 0,
            noStars: CGRect(x: 70, y: 80, width: 780, height: 360))
    drawRobot(at: CGPoint(x: 950 - 7 * k, y: horizon - CGFloat(robot.grid.count) * k + 6), scale: k, eyes: .bright)

    pixelText(robot.name.uppercased(), x: 84, y: 96, px: robot.name.count > 4 ? 22 : 26, shadow: pink) { hex(stripes[$0]) }
    pixelText("YOUR TINY PIXEL SIDEKICK", x: 88, y: 314, px: 4, color: .white, shadow: hex("#3A0E5E"))
    pixelText("FOR MACOS · RUNS ON CLAUDE CODE", x: 88, y: 364, px: 3, color: cyan, shadow: hex("#3A0E5E"))
    pixelText("TALKS · LISTENS · TAKES NOTES · HAS IDEAS", x: 88, y: 404, px: 3, color: hex("#FFB000"), shadow: hex("#3A0E5E"))
    writePNG(ctx, dir.appendingPathComponent("banner.png"))
}

private func renderHero(_ dir: URL) {
    let w: CGFloat = 840, h: CGFloat = 420, horizon: CGFloat = 340
    var frames: [CGImage] = []
    var phase: CGFloat = 0
    for (n, scene) in scenes.enumerated() {
        let start = n * 400 + 10
        let v = sprite(scene, tick: start)
        for f in 0..<26 {
            v.tick = start + f * 3
            let ctx = canvas(Int(w), Int(h))
            phase = (phase + 0.08).truncatingRemainder(dividingBy: 1)
            scenery(ctx, w: w, h: h, horizon: horizon, sun: nil, phase: phase, twinkle: f)
            drawSprite(v, ctx, x: 10, y: horizon - CGFloat(18 + robot.grid.count * 6) * 3 + 2, k: 3)
            let captionPx: CGFloat = robot.arabic ? 4 : 6
            let captionX = robot.arabic ? 820 - textWidth(scene.caption, captionPx) : 470
            pixelText(scene.caption, x: captionX, y: 50, px: captionPx, color: scene.color, shadow: hex("#3A0E5E"))
            bubble(scene.lines, x: 486, y: 150, px: 3, reveal: f * 2)
            frames.append(ctx.makeImage()!)
        }
    }
    writeGIF(frames, delay: 1.0 / 12, dir.appendingPathComponent("hero.gif"))
}

private func renderTiles(_ dir: URL) {
    let tiles: [(String, String, (SpriteView) -> Void)] = [
        ("idle", "#29B6F6", { _ in }),
        ("listening", "#2BD67B", { $0.mood = .listening }),
        ("thinking", "#9B7BFF", { $0.mood = .thinking }),
        ("talking", "#FFB000", { $0.mood = .talking }),
        ("idea", "#FF3EA5", { $0.showIdea() }),
        ("notes", "#FF6B3D", { $0.takingNotes = true }),
        ("answers", "#00C2A8", { $0.takingNotes = true; $0.showIdea() }),
        ("asleep", "#5A6BFF", { $0.asleep = true }),
    ]
    let w: CGFloat = 200, h: CGFloat = 184
    for (name, color, setup) in tiles {
        var frames: [CGImage] = []
        let v = SpriteView(frame: NSRect(x: 0, y: 0, width: 150, height: 112))
        v.tick = 10
        setup(v)
        for f in 0..<30 {
            v.tick = 10 + f * 3
            let ctx = canvas(Int(w), Int(h))
            hex(color).setFill()
            NSRect(x: 0, y: 0, width: w, height: h).fill()
            NSColor.black.withAlphaComponent(0.12).setFill()
            for gy in stride(from: 0, to: h, by: 16) { for gx in stride(from: 0, to: w, by: 16) {
                NSRect(x: gx + 7, y: gy + 7, width: 2, height: 2).fill()
            } }
            drawSprite(v, ctx, x: 0, y: 4, k: 4.0 / 3.0)
            let arabicLabels = ["idle": "هادئ", "listening": "يسمع", "thinking": "يفكّر", "talking": "يتكلّم",
                                "idea": "فكرة", "notes": "ملاحظات", "answers": "إجابات", "asleep": "نايم"]
            let label = robot.arabic ? arabicLabels[name]! : name.uppercased()
            let labelPx: CGFloat = robot.arabic ? 2 : 3
            let labelY = robot.arabic ? h - textHeight(label, labelPx) - 8 : 154
            pixelText(label, x: ((w - textWidth(label, labelPx)) / 2).rounded(), y: labelY, px: labelPx,
                      color: .white, shadow: NSColor.black.withAlphaComponent(0.35))
            frames.append(ctx.makeImage()!)
        }
        writeGIF(frames, delay: 1.0 / 12, dir.appendingPathComponent("mood-\(name).gif"))
    }
}

/// A big still of Zolt for the README footer.
private func renderSprite(_ dir: URL) {
    let ctx = canvas(14 * 16, robot.grid.count * 16)
    drawRobot(at: .zero, scale: 16)
    writePNG(ctx, dir.appendingPathComponent("\(robot.key).png"))
}

func runRenderArt(_ path: String) -> Never {
    let dir = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    renderBanner(dir)
    renderHero(dir)
    renderTiles(dir)
    renderSprite(dir)
    exit(0)
}
