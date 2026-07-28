import SwiftUI

/// Renders basic markdown text into AttributedString for rich preview
enum MarkdownRenderer {
    static func render(_ markdown: String, baseFont: Font) -> AttributedString {
        var result = AttributedString()

        let paragraphs = markdown.components(separatedBy: "\n")
        for (index, paragraph) in paragraphs.enumerated() {
            if index > 0 { result += AttributedString("\n") }
            result += renderParagraph(paragraph, baseFont: baseFont)
        }

        return result
    }

    // MARK: - Paragraph Type Detection
    private enum ParagraphType {
        case heading(level: Int, text: String)
        case blockquote(String)
        case unorderedList(String)
        case orderedList(number: Int, text: String)
        case code(String)
        case divider
        case body(String)
    }

    private static func detectParagraph(_ text: String) -> ParagraphType {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty { return .body("") }

        // Heading
        if let match = trimmed.firstMatch(of: /^(#{1,6})\s+(.+)$/) {
            let level = match.1.count
            return .heading(level: level, text: String(match.2))
        }

        // Divider
        if trimmed.firstMatch(of: /^[-*_]{3,}$/) != nil {
            return .divider
        }

        // Blockquote
        if trimmed.hasPrefix("> ") {
            return .blockquote(String(trimmed.dropFirst(2)))
        }

        // Unordered list
        if let match = trimmed.firstMatch(of: /^[-*+]\s+(.+)$/) {
            return .unorderedList(String(match.1))
        }

        // Ordered list
        if let match = trimmed.firstMatch(of: /^(\d+)\.\s+(.+)$/) {
            if let num = Int(match.1) {
                return .orderedList(number: num, text: String(match.2))
            }
        }

        // Code block (```)
        // Handled separately in the main render loop

        return .body(text)
    }

    // MARK: - Render Paragraph
    private static func renderParagraph(_ raw: String, baseFont: Font) -> AttributedString {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return AttributedString("") }

        let type = detectParagraph(raw)
        switch type {
        case .heading(let level, let text):
            return renderHeading(text, level: level, baseFont: baseFont)
        case .blockquote(let text):
            return renderBlockquote(text, baseFont: baseFont)
        case .unorderedList(let text):
            return renderListItem(text, bullet: "•", baseFont: baseFont)
        case .orderedList(let number, let text):
            return renderListItem(text, bullet: "\(number).", baseFont: baseFont)
        case .divider:
            return AttributedString(String(repeating: "—", count: 24))
                .settingAttributes(AttributeContainer().foregroundColor(.secondary))
        case .body(let text):
            return renderInline(text, baseFont: baseFont)
        case .code:
            return renderInline(trimmed, baseFont: .system(.body, design: .monospaced))
        }
    }

    // MARK: - Heading
    private static func renderHeading(_ text: String, level: Int, baseFont: Font) -> AttributedString {
        let sizes: [CGFloat] = [28, 24, 20, 18, 16, 14]
        let size = level <= sizes.count ? sizes[level - 1] : sizes.last!
        let weight: Font.Weight = level <= 2 ? .bold : .semibold

        var container = AttributeContainer()
        container.font = .system(size: size, weight: weight)
        container.foregroundColor = .brown

        return renderInline(text, baseFont: .system(size: size, weight: weight))
            .settingAttributes(container)
    }

    // MARK: - Blockquote
    private static func renderBlockquote(_ text: String, baseFont: Font) -> AttributedString {
        var line = AttributedString("  ∣  ")
        line.foregroundColor = .brown.opacity(0.4)

        let content = renderInline(text, baseFont: baseFont)
        var italic = content
        italic.font = baseFont.italic()

        var combined = line + content
        combined.foregroundColor = .secondary
        return combined
    }

    // MARK: - List Item
    private static func renderListItem(_ text: String, bullet: String, baseFont: Font) -> AttributedString {
        var bulletStr = AttributedString("  \(bullet)  ")
        bulletStr.foregroundColor = .brown.opacity(0.5)
        bulletStr.font = .system(.body, design: .monospaced)

        return bulletStr + renderInline(text, baseFont: baseFont)
    }

    // MARK: - Inline Formatting
    private static func renderInline(_ text: String, baseFont: Font) -> AttributedString {
        var result = AttributedString()
        var remaining = text

        while !remaining.isEmpty {
            if let match = remaining.firstMatch(of: /\*\*(.+?)\*\*/) {
                // Text before match
                if let range = remaining.range(of: remaining[remaining.startIndex..<match.range.lowerBound]) {
                    result += AttributedString(String(remaining[range]))
                }
                // Bold text
                var bold = AttributedString(String(match.1))
                bold.font = baseFont.bold()
                result += bold
                remaining = String(remaining[match.range.upperBound...])
            } else if let match = remaining.firstMatch(of: /\*(.+?)\*/) {
                // Text before match
                if let range = remaining.range(of: remaining[remaining.startIndex..<match.range.lowerBound]) {
                    result += AttributedString(String(remaining[range]))
                }
                // Italic text
                var italic = AttributedString(String(match.1))
                italic.font = baseFont.italic()
                result += italic
                remaining = String(remaining[match.range.upperBound...])
            } else if let match = remaining.firstMatch(of: /`(.+?)`/) {
                // Text before match
                if let range = remaining.range(of: remaining[remaining.startIndex..<match.range.lowerBound]) {
                    result += AttributedString(String(remaining[range]))
                }
                // Inline code
                var code = AttributedString(String(match.1))
                code.font = .system(.body, design: .monospaced)
                code.backgroundColor = Color.brown.opacity(0.08)
                code.foregroundColor = .brown
                result += code
                remaining = String(remaining[match.range.upperBound...])
            } else if let match = remaining.firstMatch(of: /~~(.+?)~~/) {
                if let range = remaining.range(of: remaining[remaining.startIndex..<match.range.lowerBound]) {
                    result += AttributedString(String(remaining[range]))
                }
                var strike = AttributedString(String(match.1))
                strike.strikethroughStyle = .single
                result += strike
                remaining = String(remaining[match.range.upperBound...])
            } else {
                result += AttributedString(remaining)
                break
            }
        }

        return result
    }
}

// MARK: - AttributedString Helpers
extension AttributedString {
    func settingAttributes(_ container: AttributeContainer) -> AttributedString {
        var copy = self
        copy.mergeAttributes(container)
        return copy
    }
}
