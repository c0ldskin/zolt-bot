# Contributing to Zolt 🤖

Thanks for wanting to help Zolt grow!

## Build

```bash
./build.sh              # build and install to ~/Applications
./build.sh --run        # same, then launch
./build.sh --no-install # just build into build/Zolt.app
./build.sh --release    # Apple Silicon + Intel build, zipped into build/ (how releases are made)
./build.sh --character zamil   # build Zamil, the Arabic-speaking sibling, instead of Zolt
```

Everything is plain Swift compiled with `swiftc`, so there's no Xcode project. The sources are in `Sources/`:

| File | What's inside |
|---|---|
| `Robot.swift` | The characters (Zolt and Zamil): sprite grid, colors, language, hotkey, folder |
| `main.swift` | Animations, speech bubble, voice input, Claude bridge, menu, app |
| `Notes.swift` | Meeting detection, Core Audio process tap, the note taker |
| `Clients.swift` | Per-client folders and the `memory.md` kept between calls |
| `Tasks.swift` | The ready-made tasks in the menu, and their prompts |
| `Transcriber.swift` | Live transcription with macOS 26 `SpeechAnalyzer` |
| `LiveNotes.swift` | The growing live transcript window |
| `Screen.swift` | One-off screenshots with ScreenCaptureKit |
| `Art.swift` | Renders the README banner, GIFs and tiles from the real sprite |

## Ideas for a first PR

- A new mood or animation: add it to `SpriteView.draw`, then add a tile in `Art.swift`.
- A new character: add a `Robot` in `Robot.swift` (copy Zamil as a template) and a case in `build.sh`.
- A new ready-made task: add a `ReadyTask` to the list in `Tasks.swift`.
- The dance animation on the roadmap.

## Releasing

Bump `CFBundleShortVersionString` in `Info.plist`, add a section to `CHANGELOG.md`, then push a tag like `v0.2.0`. GitHub Actions builds both apps and attaches the zips to the release.

Then update the Homebrew casks in [c0ldskin/homebrew-tap](https://github.com/c0ldskin/homebrew-tap): set `version` and the new `sha256` of each zip (`shasum -a 256 Zolt-x.y.z.zip`).

## House rules

- Keep Zolt **asking before acting**. Don't bypass the Allow/Deny hook.
- Keep meeting notes **opt-in** every time.
- If your change shows up visually, regenerate the art with `build/Zolt.app/Contents/MacOS/Zolt --render-art art`.
- Be kind. Zolt is.
