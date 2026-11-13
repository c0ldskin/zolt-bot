import Foundation

/// Ready-made tasks: things worth asking for that a newcomer wouldn't think to ask. Each one is an
/// ordinary request to Zolt's brain, so the same rules apply: the screen is looked at only for tasks
/// that say so, and anything that acts on the Mac still stops at the Allow dialog. Every reply ends
/// with a tip on how to ask for the same help in your own words.
struct ReadyTask {
    /// What a task needs from you before it starts.
    enum Needs {
        case nothing
        /// One screenshot, taken when you pick the task.
        case screen
        /// A file you choose.
        case file
        /// A line saying what you're trying to do, then one screenshot.
        case goal
        /// Your most recent meeting notes.
        case lastNotes
    }

    let title: String
    let needs: Needs
    /// `{input}` is replaced by the file path or by what you typed.
    let prompt: String
    /// Put the result on the clipboard, for drafts you'll paste somewhere.
    let copies: Bool

    /// The line every task reply ends with. Also marks where a draft stops.
    static let tipMarker = robot.t("Next time, just say:", "في المرة القادمة، قل فقط:")

    static let all: [ReadyTask] = [
        ReadyTask(title: robot.t("Summarise a document…", "لخّص مستنداً…"), needs: .file,
                  prompt: "Read the file at {input} and summarise it for me: one sentence on what it is, then the five points that matter most, then anything I need to decide or do.",
                  copies: false),
        ReadyTask(title: robot.t("Draft a reply to what's on my screen", "اكتب رداً على ما في شاشتي"), needs: .screen,
                  prompt: "Look at the message or email on my screen and draft a reply I could send. Match its tone and language, keep it short, and leave a clear [placeholder] for anything you don't know. Don't send anything.",
                  copies: true),
        ReadyTask(title: robot.t("Show me how to do something here…", "أرني كيف أفعل شيئاً هنا…"), needs: .goal,
                  prompt: "I'm trying to do this: {input}\nLook at the app on my screen and give me the next steps as a short numbered list, naming the exact buttons or menus to use. Explain, don't do it for me.",
                  copies: false),
        ReadyTask(title: robot.t("Explain what's on my screen", "اشرح ما في شاشتي"), needs: .screen,
                  prompt: "Explain what I'm looking at in plain words, as if I'm new to it, and tell me the one thing I should pay attention to.",
                  copies: false),
        ReadyTask(title: robot.t("Turn my last meeting notes into a follow-up email", "حوّل ملاحظات آخر اجتماع إلى رسالة متابعة"), needs: .lastNotes,
                  prompt: "Read my meeting notes at {input} and draft a follow-up email to the people on the call: a thank you, what we agreed, who does what by when, and the open questions. Leave a clear [placeholder] for names you don't know. Don't send anything.",
                  copies: true),
        ReadyTask(title: robot.t("Plan my day", "خطّط ليومي"), needs: .nothing,
                  prompt: "Look at today's events in my Calendar and my open Reminders, then give me a short plan for the day: what to prepare for, and the three things to get done first.",
                  copies: false),
    ]

    /// The full request for the brain. `input` is the file path or what the user typed.
    func request(input: String = "") -> String {
        prompt.replacingOccurrences(of: "{input}", with: input) + """


        This is a ready-made task, so write the full result in plain text, as long as it needs \
        (a numbered list is fine). Then end with one last line starting exactly with \
        "\(ReadyTask.tipMarker)" followed by a short phrase I could say to you to get this same help myself.
        """
    }

    /// The part of a reply to copy: everything before the tip line. Nil when the tip line is missing,
    /// which means the task didn't finish (an error or a question back), so nothing should be copied.
    static func draft(in reply: String) -> String? {
        guard let tip = reply.range(of: tipMarker, options: .backwards) else { return nil }
        let text = reply[..<tip.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// The newest meeting notes file, looking inside subfolders too. Skips `memory.md` files.
    static func latestNotes(in folder: URL) -> URL? {
        let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        var newest: (URL, Date)?
        while let file = walker?.nextObject() as? URL {
            guard file.pathExtension.lowercased() == "md", file.lastPathComponent != "memory.md" else { continue }
            let changed = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if newest == nil || changed > newest!.1 { newest = (file, changed) }
        }
        return newest?.0
    }
}
