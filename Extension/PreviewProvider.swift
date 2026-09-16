import AppKit
import Foundation
import QuickLookUI
import WebKit

@objc(PreviewViewController)
final class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {
    private let webView = WKWebView(frame: .zero)
    private let renderer = MarkdownToHTMLRenderer()
    private var pendingCompletionHandler: ((Error?) -> Void)?
    private var pendingNavigation: WKNavigation?

    override func loadView() {
        view = webView
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
    }

    @objc(preparePreviewOfFileAtURL:completionHandler:)
    func preparePreviewOfFile(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        // Quick Look can request content before loading the controller's view.
        _ = view
        finishPreviewPreparation(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))
        webView.stopLoading()
        pendingCompletionHandler = completionHandler

        do {
            let markdown = try MarkdownText.load(from: url)
            let rendered = renderer.render(markdown: markdown, baseURL: url)
            pendingNavigation = webView.loadHTMLString(rendered.html, baseURL: url.deletingLastPathComponent())
            if pendingNavigation == nil {
                finishPreviewPreparation(NSError(
                    domain: "MarkdownPreviewExtension",
                    code: 1003,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to start loading the preview."]
                ))
            }
        } catch {
            webView.loadHTMLString(Self.errorHTML(error: error), baseURL: nil)
            finishPreviewPreparation(error)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let pendingNavigation, navigation === pendingNavigation else { return }
        finishPreviewPreparation(nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard let pendingNavigation, navigation === pendingNavigation else { return }
        finishPreviewPreparation(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard let pendingNavigation, navigation === pendingNavigation else { return }
        finishPreviewPreparation(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        let error = NSError(
            domain: "MarkdownPreviewExtension",
            code: 1002,
            userInfo: [NSLocalizedDescriptionKey: "Web content process terminated while rendering the preview."]
        )
        finishPreviewPreparation(error)
    }

    private func finishPreviewPreparation(_ error: Error?) {
        let completionHandler = pendingCompletionHandler
        pendingCompletionHandler = nil
        pendingNavigation = nil
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
