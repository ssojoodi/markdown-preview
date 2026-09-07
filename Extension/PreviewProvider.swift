import AppKit
import Foundation
import QuickLookUI
import WebKit

@objc(PreviewViewController)
final class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {
    private let webView = WKWebView(frame: .zero)
    private let renderer = MarkdownToHTMLRenderer()
    private var pendingCompletionHandler: ((Error?) -> Void)?
    private var didCompleteCurrentRequest = false

    override func loadView() {
        view = webView
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadHTMLString(
            "<html><body style='font:16px -apple-system; padding: 24px;'>Loading Markdown preview...</body></html>",
            baseURL: nil
        )
    }

    @objc(preparePreviewOfFileAtURL:completionHandler:)
    func preparePreviewOfFile(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        pendingCompletionHandler = completionHandler
        didCompleteCurrentRequest = false

        do {
            let markdown = try MarkdownText.load(from: url)
            let rendered = renderer.render(markdown: markdown, baseURL: url)
            webView.loadHTMLString(rendered.html, baseURL: url.deletingLastPathComponent())
        } catch {
            webView.loadHTMLString(Self.errorHTML(error: error), baseURL: nil)
            finishPreviewPreparation(error)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishPreviewPreparation(nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webView.loadHTMLString(Self.errorHTML(error: error), baseURL: nil)
        finishPreviewPreparation(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webView.loadHTMLString(Self.errorHTML(error: error), baseURL: nil)
        finishPreviewPreparation(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        let error = NSError(
            domain: "MarkdownPreviewExtension",
            code: 1002,
            userInfo: [NSLocalizedDescriptionKey: "Web content process terminated while rendering the preview."]
        )
        webView.loadHTMLString(Self.errorHTML(error: error), baseURL: nil)
        finishPreviewPreparation(error)
    }

    private func finishPreviewPreparation(_ error: Error?) {
        guard !didCompleteCurrentRequest else { return }
        didCompleteCurrentRequest = true
        let completionHandler = pendingCompletionHandler
        pendingCompletionHandler = nil
        completionHandler?(error)
    }

    private static func errorHTML(error: Error) -> String {
        let message = HTML.escape(error.localizedDescription)
        return """
        <!doctype html>
        <html>
        <body style="font:16px/1.5 -apple-system; padding:24px;">
          <h2>Unable to preview Markdown</h2>
          <p>\(message)</p>
        </body>
        </html>
        """
    }
}
