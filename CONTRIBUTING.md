# Contributing to Bolt 🤖

Thanks for wanting to help Bolt grow!

## Build

```bash
./build.sh          # build and install to ~/Applications
./build.sh --run    # same, then launch
```

Everything is plain Swift compiled with `swiftc`, so there's no Xcode project. The sources are in `Sources/`:

| File | What's inside |
|---|---|
| `main.swift` | Sprite and animations, speech bubble, voice input, Claude bridge, menu, app |
| `Notes.swift` | Meeting detection, Core Audio process tap, the note taker |
| `Transcriber.swift` | Live transcription with macOS 26 `SpeechAnalyzer` |
| `LiveNotes.swift` | The growing live transcript window |
| `Screen.swift` | One-off screenshots with ScreenCaptureKit |
| `Art.swift` | Renders the README banner, GIFs and tiles from the real sprite |

## Ideas for a first PR

- A new mood or animation: add it to `SpriteView.draw`, then add a tile in `Art.swift`.
- A new skin: another pixel grid plus palette.
- The dance animation on the roadmap.

## House rules

- Keep Bolt **asking before acting**. Don't bypass the Allow/Deny hook.
- Keep meeting notes **opt-in** every time.
- If your change shows up visually, regenerate the art with `build/Bolt.app/Contents/MacOS/Bolt --render-art art`.
- Be kind. Bolt is.
