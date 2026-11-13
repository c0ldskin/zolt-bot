# Changelog

## Unreleased

**Remembers your clients**
- Pick a client for a call (menu → *Client for this call*, or in the "Take notes?" offer) and the notes are filed in that client's folder
- After the call, a short `memory.md` for that client is rewritten: people, what they want, concerns, commitments, next steps and open questions
- On the next call with them, suggested answers can draw on that memory, labelled "Past calls with …"
- The client is cleared when the notes are written, so a call never lands in the wrong client's memory by accident
- The memory update runs with every tool turned off, like summaries and suggested answers

**Ready-made tasks**
- A new menu of things worth asking for: summarise a document, draft a reply to what's on screen, show me how to do something in this app, explain what's on screen, turn the last meeting notes into a follow-up email, plan my day
- Every result ends with "Next time, just say: …", so you learn to ask for it yourself
- Drafts are copied to the clipboard, ready to paste; long results aren't read aloud
- Same rules as any request: one screenshot only for tasks that say so, and anything that acts on your Mac still asks first

**Prepare for a call**
- Add PDFs, PowerPoints (with speaker notes), Word files, text files, folders or web pages from the menu before a call
- Suggested answers use the passages that match each question and name their source
- Passages are found on your Mac, and requests still run with every tool turned off

## 0.3.2 · 2026-11-08

- Shell commands that name a secret location (`.ssh`, `.aws`, Keychains, `.env` files and the rest) are now refused outright instead of going to the Allow dialog
- `.env.*` files are also recognised when named without a folder
- Docs say exactly what the secret block covers, and that Claude Code needs a paid Claude account

## 0.3.1 · 2026-11-02

- When Zolt and Zamil both run, only one of them offers to take notes for a meeting
- New [SAFETY.md](SAFETY.md): what Zolt can and can't do, what leaves your Mac, and known limits
- README opens with a "Safe by design" summary

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
