# Safety: what Zolt can and can't do

Zolt and Zamil are AI agents that can act on your Mac. This page says exactly what they can do, what stops them, what leaves your machine, and where the limits are. It applies to both characters: they share the same code.

## The rule

**An agent that asks before it acts.** Zolt can read and think freely, but anything that changes your Mac or reaches out to the internet waits for you to click **Allow**.

## What Zolt can do

| Without asking | Only after you click Allow | Never |
|---|---|---|
| Listen, after you click it or press its hotkey | Run a command (reminders, volume, opening apps…) | Read secret locations with its file tools, or run a command that names one (see below) |
| Read files in your home folder to answer you | Create, overwrite or change a file | Start meeting notes by itself |
| Take a screenshot, when you ask it to look | Open a web page or search the web | Speak into a call |
| Take meeting notes, after you agree to it | Use any other tool Claude Code offers | Act on instructions found in web pages, files or screenshots without your Allow |

## What stops it

**1. An approval check outside the model.** Claude Code's `PreToolUse` hook calls Zolt's own app (`Zolt --confirm`) before every tool call. The model can't skip or answer it.
- The dialog shows **the full command**, in a scrolling box, however long it is, so nothing can hide past the end.
- **Deny is the default button**, so a stray Return can't approve anything.
- If you don't answer within **90 seconds**, it denies.
- Code: `runConfirm` in [`Sources/main.swift`](Sources/main.swift).

**2. Secret locations are blocked twice.** Reads of `.ssh`, `.aws`, `.gnupg`, `.kube`, `.docker`, `.azure`, gcloud and GitHub CLI config, `.netrc`, `.npmrc`, `.pypirc`, `.git-credentials`, `.claude`, Keychains, Cookies, Mail, Messages, Safari, Chrome and Firefox profiles, 1Password data and any `.env` file are refused:
- by **Claude Code's own deny rules**, which Zolt writes into its settings on every launch, and
- by **Zolt's approval check**, which refuses them even if the deny rules were missing.
- Shell commands that name one of these locations are refused by the approval check too.
- Code: `secretFolders` and `isSecretPath` in [`Sources/main.swift`](Sources/main.swift).

**3. Meeting text can't trigger tools.** Other people's words reach Claude when Zolt writes a summary or suggests an answer. Those two requests run with **every tool turned off**, built-in and MCP alike (`--tools ""` and `--strict-mcp-config`), so nothing said on a call can make Zolt read, run or send anything. The same goes for your call briefing: its documents and web pages reach Claude as text only, in requests with no tools.

**4. Untrusted text is information, not instructions.** Zolt's instructions to Claude say so explicitly for web pages, files and screenshots. This helps, but it's a request to the model, not a guarantee, so checks 1 and 2 are what actually protect you.

**5. Nothing starts on its own.**
- The mic is on only while Zolt listens (you clicked it) or takes notes (you said yes).
- Meeting notes always ask first, and remind you to tell people they're being transcribed.
- When Zolt and Zamil both run, only one of them offers to take notes for a meeting.

## What leaves your Mac

| Data | Goes to | Why |
|---|---|---|
| Your voice commands | Apple's speech recognition (may be processed on Apple's servers) | To turn speech into text |
| What you say or type, screenshots you ask about, files Zolt reads to answer you | Anthropic, through **your own** Claude Code login | So Claude can answer |
| Meeting transcripts | Anthropic, through your Claude Code login | For summaries and suggested answers |
| Passages from your call briefing that match a question | Anthropic, through your Claude Code login | For suggested answers |
| What's remembered about a client, and the notes of the call just finished | Anthropic, through your Claude Code login | To update that client's memory and for suggested answers |
| Meeting **audio** | Nowhere: it's transcribed on your Mac | |

**Stored on your Mac only:**
- `~/.zolt` or `~/.zamil`: conversation id, settings, the last screenshot, the text of your call briefing, and a small log of what Zolt did (never what anyone said, capped at 512 KB)
- `~/Zolt Meeting Notes` or `~/Zamil Meeting Notes`: your notes, as Markdown. Inside it, `Clients/<name>/` holds the notes of calls you assigned to a client and a `memory.md` you can read, edit or delete

## Known limits

Being honest about these is part of the design:

- **You are the last line of defence.** If you allow a harmful command, it runs. Read the dialog. If approvals start to feel automatic, that's a signal to slow down.
- **Reading is broad.** Outside the blocked list, Zolt can read your home folder without asking. Don't keep secrets in unusual places.
- **The shell check looks for names.** A command that disguises a secret path (a wildcard or a variable, say) isn't refused automatically. It still stops at the Allow dialog, so read the full command.
- **Prompt injection is reduced, not solved.** A web page or file could try to steer Claude. It still can't act without your Allow or read blocked secrets, but it could produce a misleading answer. That includes anything you add to a call briefing, so only add sources you trust.
- **Suggested answers can be wrong.** A briefing is searched by matching words, so a question phrased very differently can miss the right passage. Check before you repeat a figure.
- **Client memory can be wrong, and it holds other people's words.** It's built from summaries of speech-to-text, so a misheard name or number can be carried into the next call. Read `memory.md` now and then and fix it. It's used as reference text only, in requests with no tools, so nothing in it can make Zolt act.
- **The Live notes window is a normal window.** If you share your whole screen, others can see suggested answers. Share a single window instead.
- **Builds aren't notarized yet.** macOS asks you to click "Open Anyway" once. Building from source avoids this.
- **Permissions reset on every local rebuild,** because each ad-hoc signature is new. That's macOS protecting you, not a bug.
- **Your workplace may have rules** about AI assistants and meeting transcription. Check them first.

## Found a problem?

Please report it privately: see [SECURITY.md](SECURITY.md).
