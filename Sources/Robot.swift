import Cocoa
import Carbon.HIToolbox

/// Which character this app is. Zolt and Zamil are the same app with a different face, language,
/// folder and hotkey, so both can run side by side without stepping on each other.
/// Chosen by the `RobotCharacter` key in Info.plist (build.sh sets it), or `--character <key>`.
struct Robot {
    let key: String
    let name: String
    /// Sprite rows, each 14 wide. `e` marks the eyes' row, `m` the mouth.
    let grid: [String]
    let palette: [Character: NSColor]
    /// Speech recognition language for voice commands.
    let locale: String
    let arabic: Bool
    let hotKeyCode: Int
    let hotKeyLabel: String
    let hotKeySignature: OSType
    /// Voices offered in the Voice menu, and the default.
    let voices: [String]

    /// ~/.zolt or ~/.zamil: conversation id, settings, screenshot and log.
    var folder: URL { URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".\(key)") }
    var notesFolder: URL { URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("\(name) Meeting Notes") }

    /// Picks the English or Arabic wording.
    func t(_ english: String, _ arabicText: String) -> String { arabic ? arabicText : english }

    static let zolt = Robot(
        key: "zolt", name: "Zolt",
        grid: [
            "..o........o..",
            "..oa......ao..",
            "..oaooooooao..",
            "...obbbbbbo...",
            "..obbllllbbo..",
            "..obssssssbo..",
            "..obeesseebo..",
            "..obssssssbo..",
            "..obbbbbbbbo..",
            "..obmmmmmmbo..",
            "..obbbbbbbbo..",
            "...obbbbbbo...",
            "....oooooo....",
        ],
        palette: ["o": hex("#0C447C"), "b": hex("#378ADD"), "l": hex("#B5D4F4"), "a": hex("#EF9F27"),
                  "s": hex("#042C53"), "e": hex("#85B7EB"), "m": hex("#D3D1C7")],
        locale: "en-US", arabic: false,
        hotKeyCode: kVK_Space, hotKeyLabel: "⌃⌥Space", hotKeySignature: 0x5A4F_4C54, // "ZOLT"
        voices: ["Zarvox", "Trinoids", "Fred", "Albert", "Junior", "Ralph", "Normal"])

    /// Zamil (زميل, "companion"): Zolt's Arabic-speaking sibling, in a red-and-white shemagh and black agal.
    static let zamil = Robot(
        key: "zamil", name: "Zamil",
        grid: [
            "....wwwwww....",   // Shemagh over the crown: white with a red diamond print.
            "...wwrwwrww...",
            "..kkkkkkkkkk..",   // Agal, the black cord holding it in place.
            ".wrwwwwwwwwrw.",
            "wwrwoooooowrww",
            "wwobbbbbbbboww",
            "wrobllllllborw",
            "wwossssssssoww",
            "rwoseesseesowr",
            "wwossssssssoww",
            "wrobbbbbbbborw",
            "wwobmmmmmmboww",
            "r.obbbbbbbbo.r",   // Red fringe at the ends.
            ".r.obbbbbbo.r.",
            "....oooooo....",
        ],
        palette: ["o": hex("#1E2A3A"), "b": hex("#5C7C9C"), "l": hex("#A9C2DB"), "s": hex("#0E1A26"),
                  "e": hex("#7FE0FF"), "m": hex("#D3D1C7"), "r": hex("#C8323C"), "w": hex("#F4F1EA"),
                  "k": hex("#111111")],
        locale: "ar-SA", arabic: true,
        hotKeyCode: kVK_ANSI_Z, hotKeyLabel: "⌃⌥Z", hotKeySignature: 0x5A41_4D4C, // "ZAML"
        voices: ["Majed"])

    static let current: Robot = {
        let args = CommandLine.arguments
        let chosen = args.firstIndex(of: "--character").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
            ?? Bundle.main.object(forInfoDictionaryKey: "RobotCharacter") as? String
        return chosen == "zamil" ? .zamil : .zolt
    }()
}

let robot = Robot.current
