import Foundation
import QuickLookUI
import UniformTypeIdentifiers

struct RenderedPreview {
    let html: String
    let attachments: [String: QLPreviewReplyAttachment]
}

final class MarkdownToHTMLRenderer {
    private var attachments: [String: QLPreviewReplyAttachment] = [:]
    private var attachmentCounter: Int = 0

    func render(markdown: String, baseURL: URL) -> RenderedPreview {
        attachments = [:]
        attachmentCounter = 0

        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var body: [String] = []
        var paragraphLines: [String] = []
        var quoteLines: [String] = []
        var codeLines: [String] = []
        var inCodeBlock = false
        var codeLanguage = ""
        var listType: ListType = .none

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            let text = paragraphLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                body.append("<p>\(renderInline(text, baseURL: baseURL))</p>")
            }
            paragraphLines.removeAll(keepingCapacity: true)
        }

        func flushQuote() {
            guard !quoteLines.isEmpty else { return }
            let quoteText = quoteLines.joined(separator: "<br />")
            body.append("<blockquote><p>\(quoteText)</p></blockquote>")
            quoteLines.removeAll(keepingCapacity: true)
        }

        func closeList() {
            switch listType {
            case .unordered:
                body.append("</ul>")
            case .ordered:
                body.append("</ol>")
            case .none:
                break
            }
            listType = .none
        }

        func closeCodeBlockIfNeeded() {
            guard inCodeBlock else { return }
            let languageClass = codeLanguage.isEmpty ? "" : " class=\"language-\(escapeHTML(codeLanguage))\""
            let codeText = escapeHTML(codeLines.joined(separator: "\n"))
            body.append("<pre><code\(languageClass)>\(codeText)</code></pre>")
            inCodeBlock = false
            codeLanguage = ""
            codeLines.removeAll(keepingCapacity: true)
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if inCodeBlock {
                if trimmed.hasPrefix("```") {
                    closeCodeBlockIfNeeded()
                } else {
                    codeLines.append(line)
                }
                continue
            }

            if trimmed.hasPrefix("```") {
                flushParagraph()
                flushQuote()
                closeList()
                inCodeBlock = true
                codeLanguage = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                flushQuote()
                closeList()
                continue
            }

            if let heading = headingMatch(from: trimmed) {
                flushParagraph()
                flushQuote()
                closeList()
                body.append("<h\(heading.level)>\(renderInline(heading.text, baseURL: baseURL))</h\(heading.level)>")
                continue
            }

            if isThematicBreak(trimmed) {
                flushParagraph()
                flushQuote()
                closeList()
                body.append("<hr />")
                continue
            }

            if let quote = quoteLine(from: line) {
                flushParagraph()
                closeList()
                quoteLines.append(renderInline(quote, baseURL: baseURL))
                continue
            }

            flushQuote()

            if let unorderedItem = unorderedListItem(from: trimmed) {
                flushParagraph()
                if listType != .unordered {
                    closeList()
                    body.append("<ul>")
                    listType = .unordered
                }
                body.append("<li>\(renderInline(unorderedItem, baseURL: baseURL))</li>")
                continue
            }

            if let orderedItem = orderedListItem(from: trimmed) {
                flushParagraph()
                if listType != .ordered {
                    closeList()
                    body.append("<ol>")
                    listType = .ordered
                }
                body.append("<li>\(renderInline(orderedItem, baseURL: baseURL))</li>")
                continue
            }

            closeList()
            paragraphLines.append(trimmed)
        }

        closeCodeBlockIfNeeded()
        flushParagraph()
        flushQuote()
        closeList()

        let html = wrapDocument(body.joined(separator: "\n"))
        return RenderedPreview(html: html, attachments: attachments)
    }

    private func wrapDocument(_ body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset=\"utf-8\" />
          <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
          <style>
            :root { color-scheme: light dark; }
            body {
              margin: 24px auto;
              max-width: 860px;
              padding: 0 24px;
              font: 16px/1.55 -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif;
            }
            h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin-top: 1.1em; }
            p, ul, ol, blockquote, pre { margin: 0.7em 0; }
            code {
              font: 13px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace;
              background: rgba(128, 128, 128, 0.15);
              border-radius: 4px;
              padding: 0.1em 0.35em;
            }
            pre {
              background: rgba(128, 128, 128, 0.12);
              border-radius: 8px;
              padding: 12px;
              overflow-x: auto;
            }
            pre code {
              background: none;
              padding: 0;
              border-radius: 0;
            }
            blockquote {
              border-left: 4px solid rgba(128, 128, 128, 0.5);
              margin-left: 0;
              padding-left: 12px;
              opacity: 0.95;
            }
            img {
              max-width: 100%;
              height: auto;
              border-radius: 6px;
            }
            a { text-decoration-thickness: 1.5px; }
            .missing-image {
              color: #b04a3a;
              font-style: italic;
            }
          </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private func renderInline(_ text: String, baseURL: URL) -> String {
        let chars = Array(text)
        var output = ""
        var index = 0

        while index < chars.count {
            if let (rendered, next) = parseCodeSpan(chars: chars, from: index) {
                output += rendered
                index = next
                continue
            }
            if let (rendered, next) = parseImage(chars: chars, from: index, baseURL: baseURL) {
                output += rendered
                index = next
                continue
            }
            if let (rendered, next) = parseLink(chars: chars, from: index, baseURL: baseURL) {
                output += rendered
                index = next
                continue
            }
            if let (rendered, next) = parseDelimited(chars: chars, from: index, delimiter: "**", tag: "strong", baseURL: baseURL) {
                output += rendered
                index = next
                continue
            }
            if let (rendered, next) = parseDelimited(chars: chars, from: index, delimiter: "~~", tag: "del", baseURL: baseURL) {
                output += rendered
                index = next
                continue
            }
            if let (rendered, next) = parseDelimited(chars: chars, from: index, delimiter: "*", tag: "em", baseURL: baseURL) {
                output += rendered
                index = next
                continue
            }

            output += escapeHTML(String(chars[index]))
            index += 1
        }

        return output
    }

    private func parseCodeSpan(chars: [Character], from index: Int) -> (String, Int)? {
        guard chars[index] == "`" else { return nil }
        guard let end = findSequence("`", in: chars, from: index + 1) else { return nil }
        let content = String(chars[(index + 1)..<end])
        return ("<code>\(escapeHTML(content))</code>", end + 1)
    }

    private func parseImage(chars: [Character], from index: Int, baseURL: URL) -> (String, Int)? {
        guard index + 1 < chars.count, chars[index] == "!", chars[index + 1] == "[" else { return nil }
        guard let closeBracket = findCharacter("]", in: chars, from: index + 2) else { return nil }
        guard closeBracket + 1 < chars.count, chars[closeBracket + 1] == "(" else { return nil }
        guard let closeParen = findCharacter(")", in: chars, from: closeBracket + 2) else { return nil }

        let alt = String(chars[(index + 2)..<closeBracket])
        let destination = String(chars[(closeBracket + 2)..<closeParen]).trimmingCharacters(in: .whitespaces)
        let rendered = renderImage(alt: alt, destination: destination, baseURL: baseURL)
        return (rendered, closeParen + 1)
    }

    private func parseLink(chars: [Character], from index: Int, baseURL: URL) -> (String, Int)? {
        guard chars[index] == "[" else { return nil }
        guard let closeBracket = findCharacter("]", in: chars, from: index + 1) else { return nil }
        guard closeBracket + 1 < chars.count, chars[closeBracket + 1] == "(" else { return nil }
        guard let closeParen = findCharacter(")", in: chars, from: closeBracket + 2) else { return nil }

        let label = String(chars[(index + 1)..<closeBracket])
        let destination = String(chars[(closeBracket + 2)..<closeParen]).trimmingCharacters(in: .whitespaces)
        let href = normalizeLinkDestination(destination, baseURL: baseURL)
        let rendered = "<a href=\"\(escapeHTML(href))\">\(renderInline(label, baseURL: baseURL))</a>"
        return (rendered, closeParen + 1)
    }

    private func parseDelimited(chars: [Character], from index: Int, delimiter: String, tag: String, baseURL: URL) -> (String, Int)? {
        let delimiterChars = Array(delimiter)
        guard matches(delimiterChars, in: chars, at: index) else { return nil }

        let start = index + delimiterChars.count
        guard let end = findSequence(delimiter, in: chars, from: start) else { return nil }
        let content = String(chars[start..<end])
        let rendered = "<\(tag)>\(renderInline(content, baseURL: baseURL))</\(tag)>"
        return (rendered, end + delimiterChars.count)
    }

    private func renderImage(alt: String, destination: String, baseURL: URL) -> String {
        guard !destination.isEmpty else {
            return "<span class=\"missing-image\">[Missing image destination]</span>"
        }

        if destination.lowercased().hasPrefix("http://") || destination.lowercased().hasPrefix("https://") || destination.lowercased().hasPrefix("data:") {
            return "<img src=\"\(escapeHTML(destination))\" alt=\"\(escapeHTML(alt))\" />"
        }

        guard let fileURL = resolveLocalPath(destination, baseURL: baseURL) else {
            return "<span class=\"missing-image\">[Missing image: \(escapeHTML(destination))]</span>"
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return "<span class=\"missing-image\">[Missing image: \(escapeHTML(destination))]</span>"
        }

        // Prefer a file URL for WKWebView-backed previews.
        let src = escapeHTML(fileURL.absoluteString)
        // Keep attachment support populated for potential data-based Quick Look paths.
        let ext = fileURL.pathExtension.lowercased()
        let contentType = UTType(filenameExtension: ext) ?? .data
        attachmentCounter += 1
        let cid = "img\(attachmentCounter)"
        attachments[cid] = QLPreviewReplyAttachment(data: data, contentType: contentType)
        return "<img src=\"\(src)\" alt=\"\(escapeHTML(alt))\" />"
    }

    private func normalizeLinkDestination(_ destination: String, baseURL: URL) -> String {
        if destination.isEmpty {
            return "#"
        }

        if destination.hasPrefix("#") {
            return destination
        }

        if let parsed = URL(string: destination), parsed.scheme != nil {
            return destination
        }

        if let fileURL = resolveLocalPath(destination, baseURL: baseURL) {
            return fileURL.absoluteString
        }

        return destination
    }

    private func resolveLocalPath(_ path: String, baseURL: URL) -> URL? {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }

        return baseURL.deletingLastPathComponent().appendingPathComponent(path).standardizedFileURL
    }

    private func headingMatch(from line: String) -> (level: Int, text: String)? {
        var level = 0
        for char in line {
            if char == "#" {
                level += 1
            } else {
                break
            }
        }

        guard (1...6).contains(level) else { return nil }
        let start = line.index(line.startIndex, offsetBy: level)
        guard start < line.endIndex, line[start] == " " else { return nil }

        let textStart = line.index(after: start)
        let content = String(line[textStart...]).trimmingCharacters(in: .whitespaces)
        return (level, content)
    }

    private func quoteLine(from line: String) -> String? {
        let trimmedLeading = line.trimmingCharacters(in: .whitespaces)
        guard trimmedLeading.hasPrefix(">") else { return nil }
        var raw = trimmedLeading.dropFirst()
        if raw.first == " " {
            raw = raw.dropFirst()
        }
        return String(raw)
    }

    private func unorderedListItem(from line: String) -> String? {
        guard line.count >= 2 else { return nil }
        let prefix = line.prefix(2)
        if prefix == "- " || prefix == "* " || prefix == "+ " {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private func orderedListItem(from line: String) -> String? {
        var numberEnd: String.Index?
        for index in line.indices {
            if line[index].isNumber {
                numberEnd = line.index(after: index)
                continue
            }
            break
        }

        guard let endDigits = numberEnd else { return nil }
        guard endDigits < line.endIndex, line[endDigits] == "." else { return nil }

        let afterDot = line.index(after: endDigits)
        guard afterDot < line.endIndex, line[afterDot] == " " else { return nil }

        let contentStart = line.index(after: afterDot)
        return String(line[contentStart...]).trimmingCharacters(in: .whitespaces)
    }

    private func isThematicBreak(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        return compact == "---" || compact == "***" || compact == "___"
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func findCharacter(_ character: Character, in chars: [Character], from start: Int) -> Int? {
        guard start < chars.count else { return nil }
        for index in start..<chars.count {
            if chars[index] == character {
                return index
            }
        }
        return nil
    }

    private func matches(_ needle: [Character], in chars: [Character], at index: Int) -> Bool {
        guard index + needle.count <= chars.count else { return false }
        for offset in 0..<needle.count {
            if chars[index + offset] != needle[offset] {
                return false
            }
        }
        return true
    }

    private func findSequence(_ sequence: String, in chars: [Character], from start: Int) -> Int? {
        let needle = Array(sequence)
        guard !needle.isEmpty else { return nil }
        guard start < chars.count else { return nil }

        for index in start..<chars.count {
            if matches(needle, in: chars, at: index) {
                return index
            }
        }

        return nil
    }
}

private enum ListType {
    case none
    case unordered
    case ordered
}
