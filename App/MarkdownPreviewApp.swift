import SwiftUI
import WebKit

@main
struct MarkdownPreviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let launchTime = Date()
    @StateObject private var openDocumentState = OpenDocumentState.shared

    var body: some Scene {
        WindowGroup {
            AppPreviewView(
                launchTime: launchTime,
                binaryTime: Self.binaryModificationDate()
            )
            .environmentObject(openDocumentState)
            .onOpenURL { url in
                openDocumentState.open(url: url)
            }
        }
        .windowResizability(.contentSize)
    }

    private static func binaryModificationDate() -> Date? {
        guard let executableURL = Bundle.main.executableURL else { return nil }
        let values = try? executableURL.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }
}

final class OpenDocumentState: ObservableObject {
    static let shared = OpenDocumentState()

    @Published private(set) var openedURL: URL?

    private init() {}

    func open(url: URL) {
        DispatchQueue.main.async {
            self.openedURL = url
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        OpenDocumentState.shared.open(url: url)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        OpenDocumentState.shared.open(url: URL(fileURLWithPath: filename))
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let filename = filenames.first else {
            sender.reply(toOpenOrPrint: .failure)
            return
        }

        OpenDocumentState.shared.open(url: URL(fileURLWithPath: filename))
        sender.reply(toOpenOrPrint: .success)
    }
}

private struct AppPreviewView: View {
    let launchTime: Date
    let binaryTime: Date?

    @EnvironmentObject private var openDocumentState: OpenDocumentState
    @State private var selectedFileURL: URL?
    @State private var selectedFilePath: String = "No file selected"
    @State private var renderedHTML: String = "<html><body style='font: 15px -apple-system; padding:20px;'>Choose a Markdown file to preview.</body></html>"

    private let renderer = MarkdownToHTMLRenderer()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
//            Text("Markdown Preview")
//                .font(.title2).bold()
//
//            HStack(spacing: 10) {
//                Button("Choose Markdown File") {
//                    chooseFile()
//                }
//                Button("Reload") {
//                    reloadSelectedFile()
//                }
//                .disabled(selectedFileURL == nil)
//            }
//
//            Text("Selected: \(selectedFilePath)")
//                .font(.system(.caption, design: .monospaced))
//                .lineLimit(2)
//
//            HStack(spacing: 20) {
//                Text("Launch timestamp: \(timestampString(from: launchTime))")
//                    .font(.system(.caption, design: .monospaced))
//                Text("Binary timestamp: \(timestampString(from: binaryTime))")
//                    .font(.system(.caption, design: .monospaced))
//            }
//
//            Divider()

            WebPreview(html: renderedHTML, baseURL: selectedFileURL?.deletingLastPathComponent())
                .frame(minWidth: 840, minHeight: 540)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(20)
        .frame(minWidth: 980, minHeight: 720)
        .onAppear {
            autoLoadReadmeIfAvailable()
        }
        .onReceive(openDocumentState.$openedURL.compactMap { $0 }) { url in
            loadSelectedFile(url)
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Choose a Markdown file"

        if panel.runModal() == .OK, let url = panel.url {
            loadSelectedFile(url)
        }
    }

    private func autoLoadReadmeIfAvailable() {
        if let openedURL = openDocumentState.openedURL {
            loadSelectedFile(openedURL)
            return
        }

        guard selectedFileURL == nil else { return }

        let workingDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let readme = workingDir.appendingPathComponent("README.md")
        if FileManager.default.fileExists(atPath: readme.path) {
            loadSelectedFile(readme)
        }
    }

    private func reloadSelectedFile() {
        guard let url = selectedFileURL else { return }
        render(url: url)
    }

    private func loadSelectedFile(_ url: URL) {
        selectedFileURL = url
        selectedFilePath = url.path
        render(url: url)
    }

    private func render(url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let markdown = try loadText(from: url)
            let rendered = renderer.render(markdown: markdown, baseURL: url)
            renderedHTML = rendered.html
        } catch {
            renderedHTML = """
            <html>
              <body style='font:15px -apple-system; padding:20px;'>
                <h3>Unable to render \(escapeHTML(url.lastPathComponent))</h3>
                <p>\(escapeHTML(error.localizedDescription))</p>
              </body>
            </html>
            """
        }
    }

    private func loadText(from fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)

        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let utf16 = String(data: data, encoding: .utf16) {
            return utf16
        }
        if let iso = String(data: data, encoding: .isoLatin1) {
            return iso
        }

        throw NSError(
            domain: "MarkdownPreview",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: "Unsupported text encoding"]
        )
    }

    private func timestampString(from date: Date?) -> String {
        guard let date else { return "Unavailable" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Toronto")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS zzz"
        return formatter.string(from: date)
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

private struct WebPreview: NSViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}
