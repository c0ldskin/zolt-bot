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

private func textWidth(_ s: String, _ px: CGFloat) -> CGFloat { CGFloat(s.count) * 6 * px - px }

/// Draws pixel text with its top-left at (x, y). `color` gets the glyph row, for stripey fills.
private func pixelText(_ s: String, x: CGFloat, y: CGFloat, px: CGFloat, shadow: NSColor? = nil,
                       color: (Int) -> NSColor) {
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
    let h = CGFloat(lines.count) * px * 10 - px * 3 + pad * 2
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
        pixelText(shown, x: x + pad, y: y + pad + CGFloat(i) * px * 10, px: px, color: ink)
    }
}

// MARK: Zolt in different moods

private struct Scene {
    let caption: String
    let lines: [String]
    let color: NSColor
    let setup: (SpriteView) -> Void
}

private let scenes: [Scene] = [
    Scene(caption: "HELLO!", lines: ["HI, I'M ZOLT!", "CLICK ME & TALK."], color: cyan) { _ in },
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
    scenery(ctx, w: w, h: h, horizon: horizon, sun: (950, 230), phase: 0.35, twinkle: 0,
            noStars: CGRect(x: 70, y: 80, width: 780, height: 360))

    let k: CGFloat = 20
    drawZolt(at: CGPoint(x: 950 - 7 * k, y: horizon - 13 * k + 6), scale: k, eyes: .bright)

    let stripes = ["#FFE45C", "#FFE45C", "#FFC23D", "#FF9A3D", "#FF9A3D", "#FF6E5A", "#FF4F86"]
    pixelText("ZOLT", x: 84, y: 96, px: 26, shadow: pink) { hex(stripes[$0]) }
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
            drawSprite(v, ctx, x: 10, y: horizon - 290, k: 3)
            pixelText(scene.caption, x: 470, y: 60, px: 6, color: scene.color, shadow: hex("#3A0E5E"))
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
            let label = name.uppercased()
            pixelText(label, x: ((w - textWidth(label, 3)) / 2).rounded(), y: 154, px: 3,
                      color: .white, shadow: NSColor.black.withAlphaComponent(0.35))
            frames.append(ctx.makeImage()!)
        }
        writeGIF(frames, delay: 1.0 / 12, dir.appendingPathComponent("mood-\(name).gif"))
    }
}

/// A big still of Zolt for the README footer.
private func renderSprite(_ dir: URL) {
    let ctx = canvas(14 * 16, 13 * 16)
    drawZolt(at: .zero, scale: 16)
    writePNG(ctx, dir.appendingPathComponent("zolt.png"))
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
