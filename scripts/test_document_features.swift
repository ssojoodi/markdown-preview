// Appended to the app source by make test-native so this harness can exercise
// the window controller without widening its access level or launching the app.
import PDFKit

@main
struct DocumentFeatureTests {
    @MainActor static func main() async throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1000, height: 750))
        let window = NSWindow(contentRect: web.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = web
        let actions = DocumentActions()
        actions.webView = web
        for _ in 0..<20 { actions.changeZoom(by: 1) }
        precondition(actions.zoom == 3 && !actions.canZoomIn)
        for _ in 0..<20 { actions.changeZoom(by: -1) }
        precondition(actions.zoom == 0.5 && !actions.canZoomOut)
        actions.resetZoom()
        precondition(actions.zoom == 1)
        let other = DocumentActions()
        actions.changeZoom(by: 1)
        precondition(other.zoom == 1 && actions.zoom == 1.25)
        actions.resetZoom()
        let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/TestFixtures/features.md")
        let markdown = "# Print and zoom\n\nUnmistakable document content.\n\n```mermaid\ngraph LR\n A[Start] --> B[Middle] --> C[Finish]\n```\n\n" + (1...100).map { "Paragraph \($0): verify full document printing.\n\n" }.joined()
        let html = MarkdownToHTMLRenderer().render(markdown: markdown, baseURL: base).html
        precondition(html.contains("window.markdownRenderReady"), "Test must use the bundled renderer script")
        web.loadHTMLString(html, baseURL: base.deletingLastPathComponent())
        let deadline = Date().addingTimeInterval(20)
        while true {
            try await Task.sleep(nanoseconds: 100_000_000)
            if !web.isLoading, (try? await web.evaluateJavaScript("document.readyState")) as? String == "complete" { break }
            precondition(Date() < deadline, "WebKit load timed out")
        }
        _ = try await web.callAsyncJavaScript("await window.markdownRenderReady; return true", arguments: [:], in: nil, contentWorld: .page)
        let count = try await web.evaluateJavaScript("document.querySelectorAll('.mermaid svg').length") as! Int
        precondition(count == 1, "Mermaid must render before printing")
        actions.changeZoom(by: 2)
        try await Task.sleep(nanoseconds: 200_000_000)
        precondition(web.magnification == 1.5)
        let scale = try await web.evaluateJavaScript("window.visualViewport.scale")
        print("Zoom: 50–300% limits, reset, independent controllers; viewport scale at 150%: \(String(describing: scale))")
        for _ in 0..<20 { actions.changeZoom(by: -1) }
        try await Task.sleep(nanoseconds: 200_000_000)
        let smallScale = try await web.evaluateJavaScript("window.visualViewport.scale") as! Double
        precondition(smallScale == 0.5, "Zoom out must reach 50% in WebKit")
        actions.resetZoom()
        try await Task.sleep(nanoseconds: 200_000_000)
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        print("Default paper: \(info.paperSize), margins \(info.leftMargin), \(info.topMargin)")
        info.paperSize = NSSize(width: 612, height: 792)
        info.topMargin = 36
        info.bottomMargin = 36
        info.leftMargin = 36
        info.rightMargin = 36
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.jobDisposition = .save
        let pdf = base.deletingLastPathComponent().appendingPathComponent("print-preview.pdf")
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = pdf
        let operation = web.printOperation(with: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        let success = await actions.runPrintOperation(operation, for: window)
        precondition(success, "PDF print operation failed")
        let data = try Data(contentsOf: pdf)
        precondition(data.count > 1000)
        print("Mermaid rendered; native print operation saved \(data.count) byte PDF at \(pdf.path)")
        let document = PDFDocument(url: pdf)!
        precondition(document.pageCount > 1 && document.pageCount < 20)
        let text = document.string ?? ""
        precondition(text.contains("Paragraph 1:") && text.contains("Paragraph 100:"))
        precondition(text.contains("Start") && text.contains("Finish"))
        let invalid = MarkdownToHTMLRenderer().render(markdown: "```mermaid\nnot a diagram\n```", baseURL: base).html
        web.loadHTMLString(invalid, baseURL: base.deletingLastPathComponent())
        try await Task.sleep(nanoseconds: 100_000_000)
        while web.isLoading { try await Task.sleep(nanoseconds: 100_000_000) }
        _ = try await web.callAsyncJavaScript("""
            await Promise.race([window.markdownRenderReady,
                new Promise((_, reject) => setTimeout(() => reject(new Error('readiness did not settle')), 2000))]);
            return true;
            """, arguments: [:], in: nil, contentWorld: .page)
        print("Full multipage content verified; invalid Mermaid settles readiness")
        window.contentView = nil
        print("Document feature integration checks passed")
    }
}
