import Foundation

/// A structured AskUserQuestion prompt, parsed from the tool's raw `tool_input`
/// (carried through the blocking PermissionRequest hook). The notch renders it
/// as tappable options; the user's picks are merged back into the tool input as
/// `answers` and returned via the hook's `updatedInput` — the same closed loop
/// open-vibe-island uses, no terminal round-trip.
public struct QuestionPrompt: Sendable, Equatable {
    public struct Option: Sendable, Equatable {
        public var label: String
        public var detail: String
        /// The mirrored "Other" choice — picking it opens a freeform field
        /// (Claude Code's own prompt always offers Other, so we do too).
        public var allowsFreeform: Bool

        public init(label: String, detail: String = "", allowsFreeform: Bool = false) {
            self.label = label
            self.detail = detail
            self.allowsFreeform = allowsFreeform
        }
    }

    public struct Item: Sendable, Equatable {
        public var question: String
        public var header: String
        public var multiSelect: Bool
        public var options: [Option]

        public init(question: String, header: String = "", multiSelect: Bool = false, options: [Option]) {
            self.question = question
            self.header = header
            self.multiSelect = multiSelect
            self.options = options
        }
    }

    public var items: [Item]

    public init(items: [Item]) { self.items = items }

    /// Parse the AskUserQuestion `tool_input` JSON. Returns nil when the shape
    /// doesn't match (fall back to the plain permission card then).
    public static func parse(toolInputJSON: String) -> QuestionPrompt? {
        guard let data = toolInputJSON.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let rawQuestions = root["questions"] as? [[String: Any]], !rawQuestions.isEmpty
        else { return nil }

        var items: [Item] = []
        for raw in rawQuestions {
            guard let question = raw["question"] as? String, !question.isEmpty else { continue }
            var options: [Option] = []
            for rawOpt in (raw["options"] as? [[String: Any]]) ?? [] {
                guard let label = rawOpt["label"] as? String, !label.isEmpty else { continue }
                options.append(Option(label: label, detail: rawOpt["description"] as? String ?? ""))
            }
            guard !options.isEmpty else { continue }
            options.append(Option(label: "其他", detail: "自由输入", allowsFreeform: true))
            items.append(Item(
                question: question,
                header: raw["header"] as? String ?? "",
                multiSelect: raw["multiSelect"] as? Bool ?? false,
                options: options))
        }
        guard !items.isEmpty else { return nil }
        return QuestionPrompt(items: items)
    }

    /// Merge the user's answers (question text → answer string) into the original
    /// tool input, producing the `updatedInput` JSON the hook hands back to
    /// Claude Code ("allow the tool, but with the answers filled in").
    public static func mergeAnswers(_ answers: [String: String], intoToolInputJSON json: String) -> String? {
        guard let data = json.data(using: .utf8),
              var root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return nil }
        root["answers"] = answers
        guard let out = try? JSONSerialization.data(withJSONObject: root) else { return nil }
        return String(data: out, encoding: .utf8)
    }
}
