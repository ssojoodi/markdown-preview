import Foundation

@main
struct RendererTests {
    static func main() throws {
        let fixtureDirectory = URL(fileURLWithPath: ".build/TestFixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)

        let markdownURL = fixtureDirectory.appendingPathComponent("sample.md")
        let imageURL = fixtureDirectory.appendingPathComponent("image.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: imageURL)

        let renderer = MarkdownToHTMLRenderer()

        let basicHTML = renderer.render(
            markdown: "# Hello\n\nA **bold** [site](https://example.com).",
            baseURL: markdownURL
        ).html
        expect(basicHTML.contains("<h1>Hello</h1>"), "renders headings")
        expect(basicHTML.contains("<strong>bold</strong>"), "renders bold text")
        expect(basicHTML.contains("<a href=\"https://example.com\">site</a>"), "renders links")

        let listHTML = renderer.render(
            markdown: """
            * First Level
              * Second Level
            * First level 2
              * Second Level 2
              * Second Level 3
            """,
            baseURL: markdownURL
        ).html
        expect(listHTML.contains("<li>First Level\n<ul>\n<li>Second Level"), "renders nested unordered lists")
        expect(listHTML.contains("<li>Second Level 3"), "renders later nested list items")

        let imageHTML = renderer.render(
            markdown: "![Existing](image.png)\n\n![Missing](missing.png)",
            baseURL: markdownURL
        ).html
        expect(imageHTML.contains("<img src=\"\(imageURL.absoluteString)\" alt=\"Existing\" />"), "renders existing local images")
        expect(imageHTML.contains("[Missing image: missing.png]"), "renders missing local images as placeholders")

        let mermaidHTML = renderer.render(
            markdown: """
            ```mermaid
            graph TD
              A-->B
            ```
            """,
            baseURL: markdownURL
        ).html
        expect(mermaidHTML.contains("<div class=\"mermaid\">graph TD"), "renders Mermaid fenced code as a Mermaid container")

        let tableHTML = renderer.render(
            markdown: """
            | Name | Value |
            | --- | ---: |
            | Alpha | 1 |
            """,
            baseURL: markdownURL
        ).html
        expect(tableHTML.contains("<table>"), "renders tables")
        expect(tableHTML.contains("<th>Name</th>"), "renders table headers")
        expect(tableHTML.contains("<td style=\"text-align: right;\">1</td>"), "renders table alignment")

        print("Renderer tests passed")
    }

    private static func expect(_ condition: Bool, _ message: String) {
        if !condition {
            fputs("Test failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
