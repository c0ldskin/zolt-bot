# Changelog

## 0.3.0 · 2026-11-02

**Zamil is Arabic throughout 🇸🇦**
- Menus, dialogs, the Allow/Deny prompt, speech bubble messages and the Live notes window are all in Arabic
- Runs with an Arabic system language, so macOS lays out its menus and dialogs right to left
- Banner, animated hero and mood tiles redrawn with real Arabic pixel lettering (Kufi style), right-to-left bubbles and a mirrored banner

## 0.2.1 · 2026-11-02

- Zamil's microphone permission prompt now names its own hotkey (Control-Option-Z) instead of Zolt's
- The meeting audio permission prompt now mentions Zoom and Google Meet, not just Teams

## 0.2.0 · 2026-11-02

**Meet Zamil (زميل) 🇸🇦**, Zolt's Arabic-speaking sibling:
- Its own character in a red-and-white shemagh and black agal, with a sand-coloured app icon
- Understands spoken Arabic (Saudi) and replies in Arabic
- Arabic voice (Majed), plus an Arabic greeting and messages
- Right-to-left speech bubble and Live notes
- Its own hotkey (⌃⌥Z), folder (`~/.zamil`) and meeting notes folder, so it can run alongside Zolt
- Built from the same code: `./build.sh --character zamil`
- Meeting notes stay in English for now (no Arabic meeting transcription on macOS yet)

**Also:**
- Both apps log whether their hotkey registered, to help when two apps want the same keys

## 0.1.0 · 2026-11-02

The first public release. ⚡

**Zolt can:**
- Chat by voice (click or ⌃⌥Space) or text, in classic 80s Mac robot voices
- Do things on your Mac with your OK, such as reminders, volume and opening apps. Every action and web search shows an Allow/Deny dialog with the full command
- Look at your screen when you ask
- Take meeting notes for Teams, Zoom and Google Meet: it asks first, shows a live transcript that grows with the call, and writes a TL;DR, decisions and action items
- Suggest answers to questions asked on a call (optional, shown only in the notes window)
- Live a little: blinking, glancing, hops, ideas, naps, a meeting headset

**Safety and privacy:**
- Never reads secret locations (`.ssh`, `.aws`, Keychains, `.env` files and more)
- Meeting summaries and suggested answers run with no tools at all
- The log records what Zolt did, never what anyone said

**Under the hood:**
- A download that runs on both Apple Silicon and Intel Macs
- Idle CPU cut by about 60% (15 fps animation, 5 fps while napping, no drawing when hidden)
- Moves your settings over automatically if you used it back when it was called Bolt
