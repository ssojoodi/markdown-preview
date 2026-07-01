import SwiftUI
import AppKit
import WebKit

@main
struct MarkdownPreviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var openDocumentState = OpenDocumentState.shared

    var body: some Scene {
        WindowGroup {
            AppPreviewView()
            .environmentObject(openDocumentState)
            .onOpenURL { url in
                openDocumentState.open(url: url)
            }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Markdown Preview Help") {
                    HelpPresenter.showHelp()
                }
            }
        }
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
    @EnvironmentObject private var openDocumentState: OpenDocumentState
    @AppStorage("didCompleteQuickLookSetup") private var didCompleteQuickLookSetup = false
    @State private var selectedFileURL: URL?
    @State private var selectedFilePath: String = "No file selected"
    @State private var renderedHTML: String = PreviewHTML.emptyState
    @State private var markdownText: String = ""
    @State private var isDirty = false
    @State private var isEditMode = false

    private let renderer = MarkdownToHTMLRenderer()

    var body: some View {
        Group {
            if didCompleteQuickLookSetup {
                previewContent
            } else {
                QuickLookSetupView(
                    onOpenSettings: openQuickLookSettings,
                    onContinue: {
                        didCompleteQuickLookSetup = true
                    }
                )
            }
        }
        .frame(minWidth: 980, minHeight: 720)
        .onAppear {
            loadOpenedFileIfAvailable()
        }
        .onReceive(openDocumentState.$openedURL.compactMap { $0 }) { url in
            openDocument(url)
        }
    }

    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedFileURL?.lastPathComponent ?? "No file selected")
                        .font(.headline)
                    Text(selectedFilePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        chooseFile()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(CircleIconButtonStyle())
                    .help("Choose Markdown file")

                    Button {
                        reloadSelectedFile()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(CircleIconButtonStyle())
                    .help("Reload file")
                    .disabled(selectedFileURL == nil)

                    Button {
                        toggleEditMode()
                    } label: {
                        Image(systemName: isEditMode ? "eye" : "pencil")
                    }
                    .buttonStyle(CircleIconButtonStyle())
                    .help(isEditMode ? "Show preview" : "Edit Markdown")
                    .disabled(selectedFileURL == nil)

                    Button {
                        _ = saveCurrentFile()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(CircleIconButtonStyle(isProminent: true))
                    .help("Save changes")
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(selectedFileURL == nil || !isDirty)
                }
            }

            if isDirty {
                Text("Unsaved changes")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            if isEditMode {
                MarkdownEditor(
                    text: $markdownText,
                    isActive: isEditMode,
                    onTextChange: {
                        isDirty = true
                    }
                )
                .frame(minWidth: 840, maxWidth: .infinity, minHeight: 540, maxHeight: .infinity)
            } else {
                WebPreview(html: renderedHTML, baseURL: selectedFileURL?.deletingLastPathComponent())
                    .frame(minWidth: 840, maxWidth: .infinity, minHeight: 540, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(20)
    }

    private func chooseFile() {
        guard confirmDiscardingChangesIfNeeded() else { return }

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

    private func loadOpenedFileIfAvailable() {
        if let openedURL = openDocumentState.openedURL {
            openDocument(openedURL)
        }
    }

    private func reloadSelectedFile() {
        guard let url = selectedFileURL else { return }
        guard confirmDiscardingChangesIfNeeded() else { return }
        isEditMode = false
        loadSelectedFile(url)
    }

    private func toggleEditMode() {
        if isEditMode, let selectedFileURL {
            renderedHTML = renderer.render(markdown: markdownText, baseURL: selectedFileURL).html
        }

        isEditMode.toggle()
    }

    private func openQuickLookSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.quicklook.preview",
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        ]

        let didOpenSettings = urls.compactMap(URL.init(string:)).contains { NSWorkspace.shared.open($0) }
        guard didOpenSettings else {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/System Settings.app"), configuration: .init())
            return
        }

        didCompleteQuickLookSetup = true
    }

    private func loadSelectedFile(_ url: URL) {
        selectedFileURL = url
        selectedFilePath = url.path
        isDirty = false
        isEditMode = false
        loadMarkdownAndRender(from: url)
    }

    private func loadMarkdownAndRender(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let markdown = try MarkdownText.load(from: url)
            markdownText = markdown
            renderedHTML = renderer.render(markdown: markdown, baseURL: url).html
        } catch {
            isDirty = false
            markdownText = ""
            renderedHTML = """
            <html>
              <body style='font:15px -apple-system; padding:20px;'>
                <h3>Unable to render \(HTML.escape(url.lastPathComponent))</h3>
                <p>\(HTML.escape(error.localizedDescription))</p>
              </body>
            </html>
            """
        }
    }

    private func openDocument(_ url: URL) {
        guard confirmDiscardingChangesIfNeeded() else { return }
        didCompleteQuickLookSetup = true
        loadSelectedFile(url)
    }

    @discardableResult
    private func saveCurrentFile() -> Bool {
        guard let url = selectedFileURL else { return true }

        guard let data = markdownText.data(using: .utf8) else {
            showAlert(
                title: "Unable to save \(url.lastPathComponent)",
                message: "Cannot encode document with UTF-8."
            )
            return false
        }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try data.write(to: url, options: .atomic)
            isDirty = false
            renderedHTML = renderer.render(markdown: markdownText, baseURL: url).html
            return true
        } catch {
            showAlert(
                title: "Unable to save \(url.lastPathComponent)",
                message: error.localizedDescription
            )
            return false
        }
    }

    private func confirmDiscardingChangesIfNeeded() -> Bool {
        guard isDirty else { return true }

        let alert = NSAlert()
        alert.messageText = "Save changes to \(selectedFileURL?.lastPathComponent ?? "this document")?"
        alert.informativeText = "Your edits will be lost if you continue without saving."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveCurrentFile()
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

}

private enum PreviewHTML {
    static let emptyState = """
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8">
        <style>
          :root { color-scheme: light dark; }
          body {
            margin: 0;
            min-height: 100vh;
            display: grid;
            place-items: center;
            font: 15px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            color: CanvasText;
            background: Canvas;
          }
          main {
            max-width: 460px;
            padding: 28px;
            text-align: center;
          }
          h1 {
            margin: 0 0 10px;
            font-size: 24px;
            font-weight: 650;
          }
          p {
            margin: 0;
            color: color-mix(in srgb, CanvasText 70%, transparent);
            line-height: 1.45;
          }
        </style>
      </head>
      <body>
        <main>
          <h1>Open a Markdown file</h1>
          <p>Select a Markdown file in Finder, choose Open With > Markdown Preview, and this window will render it here.</p>
        </main>
      </body>
    </html>
    """
}

private enum HelpPresenter {
    static func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Markdown Preview"
        alert.informativeText = "Markdown Preview adds rendered Quick Look previews for Markdown files. It also gives you a quick way to open an .md or .markdown file from Finder and view it in this app."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private struct CircleIconButtonStyle: ButtonStyle {
    var isProminent = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(foregroundColor)
            .frame(width: 32, height: 32)
            .background {
                Circle()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            }
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(Circle())
            .contentShape(Circle())
            .opacity(isEnabled ? 1 : 0.45)
    }

    private var foregroundColor: Color {
        if isProminent, isEnabled {
            return .white
        }

        return .primary
    }

    private func backgroundColor(isPressed: Bool) -> some ShapeStyle {
        if isProminent, isEnabled {
            return AnyShapeStyle(Color.accentColor.opacity(isPressed ? 0.78 : 0.92))
        }

        return AnyShapeStyle(
            Color(nsColor: .controlBackgroundColor)
                .opacity(isPressed ? 0.72 : 1)
        )
    }

    private var borderColor: Color {
        if isProminent, isEnabled {
            return Color.accentColor.opacity(0.55)
        }

        return Color(nsColor: .separatorColor).opacity(0.65)
    }
}

private struct QuickLookSetupView: View {
    let onOpenSettings: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)

                    Text("Enable Markdown Preview")
                        .font(.system(size: 30, weight: .semibold))

                    Text("macOS requires you to enable new Quick Look extensions. Turn on Markdown Preview in System Settings to preview Markdown files from Finder with Space.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SetupStep(number: 1, text: "Open System Settings")
                    SetupStep(number: 2, text: "Go to General -> Login Items & Extensions -> Quick Look")
                    SetupStep(number: 3, text: "Turn on Markdown Preview")
                }

                HStack(spacing: 12) {
                    Button(action: onOpenSettings) {
                        Label("Open System Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Continue") {
                        onContinue()
                    }
                    .controlSize(.large)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let isActive: Bool
    let onTextChange: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onTextChange: onTextChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isAutomaticTextCompletionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if textView.string != text {
            textView.string = text
        }

        if isActive, textView.window?.firstResponder !== textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        let onTextChange: () -> Void
        weak var textView: NSTextView?

        init(text: Binding<String>, onTextChange: @escaping () -> Void) {
            _text = text
            self.onTextChange = onTextChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if textView.string != text {
                text = textView.string
            }
            onTextChange()
        }
    }
}

private struct SetupStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.callout)
        }
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
