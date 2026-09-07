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
            CommandGroup(replacing: .newItem) {
                Button("New Markdown File") {
                    openDocumentState.createNewDocument()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

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
    @Published private(set) var newDocumentRequestCount = 0

    private init() {}

    func open(url: URL) {
        DispatchQueue.main.async {
            self.openedURL = url
        }
    }

    func createNewDocument() {
        DispatchQueue.main.async {
            self.newDocumentRequestCount += 1
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
    @State private var isShowingRichTextConverter = false
    @State private var isUntitledDocument = false
    @State private var handledNewDocumentRequestCount = 0
    @State private var isAdvancedOptionsExpanded = false

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
        .onReceive(openDocumentState.$newDocumentRequestCount) { count in
            guard count > handledNewDocumentRequestCount else { return }
            handledNewDocumentRequestCount = count
            createNewDocument()
        }
    }

    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            advancedOptions

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
                WebPreview(html: renderedHTML, baseURL: previewBaseURL)
                    .frame(minWidth: 840, maxWidth: .infinity, minHeight: 540, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(20)
        .sheet(isPresented: $isShowingRichTextConverter) {
            RichTextMarkdownConverterSheet()
        }
    }

    private var advancedOptions: some View {
        HStack(spacing: 10) {
            if isAdvancedOptionsExpanded {
                if selectedFileURL != nil {
                    Button {
                        copySelectedFilePath()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(CircleIconButtonStyle())
                    .help(selectedFilePath)
                    .transition(.opacity)
                }

                Spacer()

                advancedActionButtons
                    .transition(.opacity)
            } else {
                Spacer()
            }

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isAdvancedOptionsExpanded.toggle()
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(CircleIconButtonStyle(isActive: isAdvancedOptionsExpanded))
            .help(isAdvancedOptionsExpanded ? "Hide advanced options" : "Show advanced options")
        }
    }

    private var advancedActionButtons: some View {
        HStack(spacing: 10) {
            Button {
                createNewDocument()
            } label: {
                Image(systemName: "doc.badge.plus")
            }
            .buttonStyle(CircleIconButtonStyle())
            .help("New Markdown file")

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
            .disabled(!canEdit)

            if isEditMode {
                Button {
                    isShowingRichTextConverter = true
                } label: {
                    Image(systemName: "doc.richtext")
                }
                .buttonStyle(CircleIconButtonStyle())
                .help("Convert rich text to Markdown")
            }

            Button {
                _ = saveCurrentFile()
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .buttonStyle(CircleIconButtonStyle(isProminent: true))
            .help("Save changes")
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!canSave)
        }
    }

    private var documentTitle: String {
        selectedFileURL?.lastPathComponent ?? (isUntitledDocument ? "Untitled.md" : "No file selected")
    }

    private var canEdit: Bool {
        selectedFileURL != nil || isUntitledDocument
    }

    private var canSave: Bool {
        selectedFileURL != nil ? isDirty : isUntitledDocument
    }

    private var renderBaseFileURL: URL {
        selectedFileURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("Untitled.md")
    }

    private var previewBaseURL: URL? {
        canEdit ? renderBaseFileURL.deletingLastPathComponent() : nil
    }

    private func createNewDocument() {
        guard confirmDiscardingChangesIfNeeded() else { return }

        selectedFileURL = nil
        selectedFilePath = "Unsaved Markdown document"
        markdownText = ""
        renderedHTML = renderer.render(markdown: "", baseURL: renderBaseFileURL).html
        isDirty = false
        isEditMode = true
        isUntitledDocument = true
        isAdvancedOptionsExpanded = true
        didCompleteQuickLookSetup = true
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

    private func copySelectedFilePath() {
        guard let path = selectedFileURL?.path else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    private func toggleEditMode() {
        if isEditMode {
            renderedHTML = renderer.render(markdown: markdownText, baseURL: renderBaseFileURL).html
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
        isUntitledDocument = false
        isDirty = false
        isEditMode = false
        isAdvancedOptionsExpanded = false
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
        guard let url = selectedFileURL ?? promptForNewFileURL() else { return false }

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
            selectedFileURL = url
            selectedFilePath = url.path
            isUntitledDocument = false
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

    private func promptForNewFileURL() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save Markdown File"
        panel.nameFieldStringValue = "Untitled.md"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return nil }
        if selectedURL.pathExtension.isEmpty {
            return selectedURL.appendingPathExtension("md")
        }
        return selectedURL
    }

    private func confirmDiscardingChangesIfNeeded() -> Bool {
        guard isDirty else { return true }

        let alert = NSAlert()
        alert.messageText = "Save changes to \(documentTitle)?"
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
    var isActive = false

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

        if isActive, isEnabled {
            return .accentColor
        }

        return .primary
    }

    private func backgroundColor(isPressed: Bool) -> some ShapeStyle {
        if isProminent, isEnabled {
            return AnyShapeStyle(Color.accentColor.opacity(isPressed ? 0.78 : 0.92))
        }

        if isActive, isEnabled {
            return AnyShapeStyle(Color.accentColor.opacity(isPressed ? 0.15 : 0.1))
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

        if isActive, isEnabled {
            return Color.accentColor.opacity(0.3)
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

private struct RichTextMarkdownConverterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var richText = NSAttributedString(string: "")
    @State private var markdown = ""
    @State private var copiedMarkdown = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Convert Rich Text")
                    .font(.headline)

                Spacer()

                Button {
                    clear()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .disabled(richText.string.isEmpty && markdown.isEmpty)

                Button {
                    copyMarkdown()
                } label: {
                    Label(copiedMarkdown ? "Copied" : "Copy Markdown", systemImage: copiedMarkdown ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .disabled(markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rich Text")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    RichTextPasteEditor(
                        attributedText: $richText,
                        onTextChange: { updatedText in
                            richText = updatedText
                            markdown = RichTextMarkdownConverter.markdown(from: updatedText)
                            copiedMarkdown = false
                        },
                        onHTMLPaste: { html in
                            markdown = RichTextMarkdownConverter.markdown(fromHTML: html)
                            copiedMarkdown = false
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Markdown")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    MarkdownOutputEditor(text: markdown)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 980, idealWidth: 1080, minHeight: 620, idealHeight: 680)
    }

    private func clear() {
        richText = NSAttributedString(string: "")
        markdown = ""
        copiedMarkdown = false
    }

    private func copyMarkdown() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        copiedMarkdown = true
    }
}

private struct RichTextPasteEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    let onTextChange: (NSAttributedString) -> Void
    let onHTMLPaste: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextChange: onTextChange, onHTMLPaste: onHTMLPaste)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = RichTextPasteTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.onHTMLPaste = onHTMLPaste
        textView.textStorage?.setAttributedString(attributedText)
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.isRichText = true
        textView.importsGraphics = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        context.coordinator.textView = textView

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        guard !context.coordinator.isUpdatingFromTextView else { return }

        if textView.attributedString() != attributedText {
            textView.textStorage?.setAttributedString(attributedText)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let onTextChange: (NSAttributedString) -> Void
        let onHTMLPaste: (String) -> Void
        weak var textView: RichTextPasteTextView?
        var isUpdatingFromTextView = false

        init(onTextChange: @escaping (NSAttributedString) -> Void, onHTMLPaste: @escaping (String) -> Void) {
            self.onTextChange = onTextChange
            self.onHTMLPaste = onHTMLPaste
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdatingFromTextView = true
            onTextChange(textView.attributedString())
            isUpdatingFromTextView = false
        }
    }
}

private final class RichTextPasteTextView: NSTextView {
    var onHTMLPaste: ((String) -> Void)?

    override func paste(_ sender: Any?) {
        let html = NSPasteboard.general.string(forType: .html)
        super.paste(sender)

        if let html, !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onHTMLPaste?(html)
        }
    }
}

private struct MarkdownOutputEditor: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView(frame: .zero)
        textView.string = text
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isRichText = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var textView: NSTextView?
    }
}

private enum RichTextMarkdownConverter {
    static func markdown(fromHTML html: String) -> String {
        var body = htmlContent(from: html)
        body = removeMatches(pattern: "<!--.*?-->", in: body)
        body = removeMatches(pattern: "<script\\b[^>]*>.*?</script>", in: body)
        body = removeMatches(pattern: "<style\\b[^>]*>.*?</style>", in: body)

        body = replaceMatches(pattern: "<pre\\b[^>]*>(.*?)</pre>", in: body) { captures in
            "\n\n\(fencedCodeBlock(fromHTML: captures[0]))\n\n"
        }

        body = replaceMatches(pattern: "<table\\b[^>]*>(.*?)</table>", in: body) { captures in
            "\n\n\(tableMarkdown(fromHTML: captures[0]))\n\n"
        }

        body = replaceMatches(pattern: "<(ul|ol)\\b[^>]*>(.*?)</\\1>", in: body) { captures in
            "\n\n\(listMarkdown(tag: captures[0], html: captures[1]))\n\n"
        }

        for level in 1...6 {
            body = replaceMatches(pattern: "<h\(level)\\b[^>]*>(.*?)</h\(level)>", in: body) { captures in
                let text = compactInlineMarkdown(fromHTML: captures[0])
                guard !text.isEmpty else { return "" }
                return "\n\n\(String(repeating: "#", count: level)) \(text)\n\n"
            }
        }

        body = replaceMatches(pattern: "<br\\s*/?>", in: body) { _ in "\n" }
        body = replaceMatches(pattern: "</(?:p|div|section|article|li)>", in: body) { _ in "\n\n" }
        body = replaceMatches(pattern: "<(?:p|div|section|article|ul|ol|li)\\b[^>]*>", in: body) { _ in "" }

        return cleanBlockMarkdown(inlineMarkdown(fromHTML: body))
    }

    static func markdown(from attributedString: NSAttributedString) -> String {
        let source = attributedString.string as NSString
        guard source.length > 0 else { return "" }

        let bodyFontSize = medianFontSize(in: attributedString)
        var paragraphs: [NSRange] = []
        var location = 0
        while location < source.length {
            let paragraphRange = source.paragraphRange(for: NSRange(location: location, length: 0))
            paragraphs.append(paragraphRange)
            location = NSMaxRange(paragraphRange)
        }

        var blocks: [String] = []
        var index = 0
        while index < paragraphs.count {
            let paragraphRange = trimmedParagraphRange(paragraphs[index], in: source)
            let plain = source.substring(with: paragraphRange)

            if plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                index += 1
                continue
            }

            if plain.contains("\t") {
                var rows: [[String]] = []
                while index < paragraphs.count {
                    let rowRange = trimmedParagraphRange(paragraphs[index], in: source)
                    let rowText = source.substring(with: rowRange)
                    guard rowText.contains("\t") else { break }
                    rows.append(rowText.components(separatedBy: "\t").map { cleanInlineText($0) })
                    index += 1
                }

                if let table = tableMarkdown(fromRows: rows) {
                    blocks.append(table)
                }
                continue
            }

            if isCodeBlock(attributedString, range: paragraphRange) {
                blocks.append(fencedCodeBlock(fromPlainText: plain))
                index += 1
                continue
            }

            let inline = inlineMarkdown(from: attributedString, range: paragraphRange)
            if let listLine = listLineMarkdown(from: inline) {
                blocks.append(listLine)
            } else if let level = headingLevel(in: attributedString, range: paragraphRange, bodyFontSize: bodyFontSize) {
                blocks.append("\(String(repeating: "#", count: level)) \(inline)")
            } else {
                blocks.append(inline)
            }

            index += 1
        }

        return cleanBlockMarkdown(joinBlocks(blocks))
    }

    private static func htmlContent(from html: String) -> String {
        if let body = firstCapture(pattern: "<body\\b[^>]*>(.*?)</body>", in: html) {
            return body
        }
        return html
    }

    private static func tableMarkdown(fromHTML html: String) -> String {
        let rowMatches = captures(pattern: "<tr\\b[^>]*>(.*?)</tr>", in: html)
        var rows: [[String]] = []

        for rowMatch in rowMatches {
            let rowHTML = rowMatch[0]
            let cellMatches = captures(pattern: "<t[hd]\\b[^>]*>(.*?)</t[hd]>", in: rowHTML)
            let cells = cellMatches.map { compactInlineMarkdown(fromHTML: $0[0]) }
            if !cells.isEmpty {
                rows.append(cells)
            }
        }

        return tableMarkdown(fromRows: rows) ?? compactInlineMarkdown(fromHTML: html)
    }

    private static func tableMarkdown(fromRows rows: [[String]]) -> String? {
        guard let firstRow = rows.first, !firstRow.isEmpty else { return nil }
        let columnCount = rows.map(\.count).max() ?? firstRow.count
        guard columnCount > 1 else { return nil }

        let normalizedRows = rows.map { row in
            row + Array(repeating: "", count: max(0, columnCount - row.count))
        }

        let header = normalizedRows[0].prefix(columnCount).map(escapeTableCell)
        let separator = Array(repeating: "---", count: columnCount)
        let bodyRows = normalizedRows.dropFirst().map { row in
            "| " + row.prefix(columnCount).map(escapeTableCell).joined(separator: " | ") + " |"
        }

        return ([
            "| " + header.joined(separator: " | ") + " |",
            "| " + separator.joined(separator: " | ") + " |"
        ] + bodyRows).joined(separator: "\n")
    }

    private static func listMarkdown(tag: String, html: String) -> String {
        let marker = tag.lowercased() == "ol" ? "1." : "-"
        let items = captures(pattern: "<li\\b[^>]*>(.*?)</li>", in: html)
            .map { listItemMarkdown(fromHTML: $0[0]) }
            .filter { !$0.isEmpty }

        guard !items.isEmpty else {
            return compactInlineMarkdown(fromHTML: html)
        }

        if marker == "1." {
            return items.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
        }

        return items.map { "- \($0)" }.joined(separator: "\n")
    }

    private static func listItemMarkdown(fromHTML html: String) -> String {
        var itemHTML = removeMatches(pattern: "<(?:ul|ol)\\b[^>]*>.*?</(?:ul|ol)>", in: html)
        itemHTML = replaceMatches(pattern: "</(?:p|div)>", in: itemHTML) { _ in " " }
        itemHTML = replaceMatches(pattern: "<(?:p|div)\\b[^>]*>", in: itemHTML) { _ in "" }
        return compactInlineMarkdown(fromHTML: itemHTML)
    }

    private static func inlineMarkdown(fromHTML html: String) -> String {
        var output = html

        output = replaceMatches(pattern: "<code\\b[^>]*>(.*?)</code>", in: output) { captures in
            inlineCodeMarkdownFromHTML(captures[0])
        }

        output = replaceMatches(pattern: "<a\\b([^>]*)>.*?<img\\b([^>]*)>.*?</a>", in: output) { captures in
            let href = attribute("href", in: captures[0])
            let src = attribute("src", in: captures[1])
            let alt = attribute("alt", in: captures[1])
            guard let src else { return "" }
            let image = "![\(escapeLinkLabel(decodeHTMLEntities(alt ?? "Image")))](\(decodeHTMLEntities(src)))"
            if let href, !href.isEmpty {
                return "[\(image)](\(decodeHTMLEntities(href)))"
            }
            return image
        }

        output = replaceMatches(pattern: "<img\\b([^>]*)>", in: output) { captures in
            guard let src = attribute("src", in: captures[0]) else { return "" }
            let alt = attribute("alt", in: captures[0]) ?? "Image"
            return "![\(escapeLinkLabel(decodeHTMLEntities(alt)))](\(decodeHTMLEntities(src)))"
        }

        output = replaceMatches(pattern: "<a\\b([^>]*)>(.*?)</a>", in: output) { captures in
            let label = compactInlineMarkdown(fromHTML: captures[1])
            guard let href = attribute("href", in: captures[0]), !href.isEmpty else { return label }
            return "[\(escapeLinkLabel(label))](\(decodeHTMLEntities(href)))"
        }

        output = replaceMatches(pattern: "<(?:strong|b)\\b[^>]*>(.*?)</(?:strong|b)>", in: output) { captures in
            "**\(compactInlineMarkdown(fromHTML: captures[0]))**"
        }

        output = replaceMatches(pattern: "<(?:em|i)\\b[^>]*>(.*?)</(?:em|i)>", in: output) { captures in
            "*\(compactInlineMarkdown(fromHTML: captures[0]))*"
        }

        output = replaceMatches(pattern: "<br\\s*/?>", in: output) { _ in "\n" }
        output = replaceMatches(pattern: "<[^>]+>", in: output) { _ in "" }
        return decodeHTMLEntities(output)
    }

    private static func compactInlineMarkdown(fromHTML html: String) -> String {
        cleanInlineText(inlineMarkdown(fromHTML: html))
    }

    private static func inlineMarkdown(from attributedString: NSAttributedString, range: NSRange) -> String {
        var output = ""
        attributedString.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
            let raw = (attributedString.string as NSString).substring(with: subrange)

            if let image = imageMarkdown(from: attributes) {
                output += image
                return
            }

            if isCode(attributes) {
                output += inlineCodeMarkdown(raw)
                return
            }

            var text = escapeInlineText(raw)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                output += text
                return
            }

            if let link = linkDestination(from: attributes) {
                text = "[\(escapeLinkLabel(cleanInlineText(text)))](\(link))"
            }

            if isItalic(attributes) {
                text = "*\(text)*"
            }

            if isBold(attributes) {
                text = "**\(text)**"
            }

            output += text
        }

        return cleanInlineText(output)
    }

    private static func imageMarkdown(from attributes: [NSAttributedString.Key: Any]) -> String? {
        guard attributes[.attachment] is NSTextAttachment else { return nil }
        let destination = linkDestination(from: attributes) ?? "image"
        let image = "![Image](\(destination))"
        if let link = linkDestination(from: attributes), link != destination {
            return "[\(image)](\(link))"
        }
        return image
    }

    private static func linkDestination(from attributes: [NSAttributedString.Key: Any]) -> String? {
        guard let link = attributes[.link] else { return nil }
        if let url = link as? URL {
            return url.absoluteString
        }
        if let string = link as? String {
            return string
        }
        return nil
    }

    private static func isBold(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
        guard let font = attributes[.font] as? NSFont else { return false }
        return NSFontManager.shared.traits(of: font).contains(.boldFontMask)
    }

    private static func isItalic(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
        guard let font = attributes[.font] as? NSFont else { return false }
        return NSFontManager.shared.traits(of: font).contains(.italicFontMask)
    }

    private static func isCode(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
        guard let font = attributes[.font] as? NSFont else { return false }
        return isMonospaced(font)
    }

    private static func isMonospaced(_ font: NSFont) -> Bool {
        let traits = NSFontManager.shared.traits(of: font)
        if traits.contains(.fixedPitchFontMask) {
            return true
        }

        return font.fontDescriptor.symbolicTraits.contains(.monoSpace)
    }

    private static func isCodeBlock(_ attributedString: NSAttributedString, range: NSRange) -> Bool {
        let plain = (attributedString.string as NSString).substring(with: range)
        guard plain.contains("\n") || plain.count >= 24 else { return false }

        var styledLength = 0
        var codeLength = 0
        attributedString.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            guard let font = value as? NSFont else { return }
            styledLength += subrange.length
            if isMonospaced(font) {
                codeLength += subrange.length
            }
        }

        guard styledLength > 0 else { return false }
        return Double(codeLength) / Double(styledLength) > 0.82
    }

    private static func headingLevel(in attributedString: NSAttributedString, range: NSRange, bodyFontSize: CGFloat) -> Int? {
        let plain = (attributedString.string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plain.isEmpty, plain.count <= 140 else { return nil }

        var largestFontSize: CGFloat = bodyFontSize
        var boldCharacters = 0
        var styledCharacters = 0

        attributedString.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
            guard let font = attributes[.font] as? NSFont else { return }
            largestFontSize = max(largestFontSize, font.pointSize)
            styledCharacters += subrange.length
            if NSFontManager.shared.traits(of: font).contains(.boldFontMask) {
                boldCharacters += subrange.length
            }
        }

        let boldRatio = styledCharacters == 0 ? 0 : Double(boldCharacters) / Double(styledCharacters)
        if largestFontSize >= bodyFontSize + 12 {
            return 1
        }
        if largestFontSize >= bodyFontSize + 7 {
            return 2
        }
        if largestFontSize >= bodyFontSize + 3, boldRatio > 0.55 {
            return 3
        }
        return nil
    }

    private static func medianFontSize(in attributedString: NSAttributedString) -> CGFloat {
        var sizes: [CGFloat] = []
        let fullRange = NSRange(location: 0, length: attributedString.length)
        attributedString.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let font = value as? NSFont else { return }
            sizes.append(contentsOf: Array(repeating: font.pointSize, count: max(1, min(range.length, 12))))
        }

        guard !sizes.isEmpty else { return NSFont.systemFontSize }
        sizes.sort()
        return sizes[sizes.count / 2]
    }

    private static func trimmedParagraphRange(_ range: NSRange, in source: NSString) -> NSRange {
        var start = range.location
        var length = range.length

        while length > 0 {
            let scalar = source.character(at: start)
            guard CharacterSet.newlines.contains(UnicodeScalar(scalar) ?? "\0") else { break }
            start += 1
            length -= 1
        }

        while length > 0 {
            let scalar = source.character(at: start + length - 1)
            guard CharacterSet.newlines.contains(UnicodeScalar(scalar) ?? "\0") else { break }
            length -= 1
        }

        return NSRange(location: start, length: length)
    }

    private static func attribute(_ name: String, in htmlTagAttributes: String) -> String? {
        let pattern = "\(name)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
        let matches = captures(pattern: pattern, in: htmlTagAttributes, options: [.caseInsensitive])
        guard let first = matches.first else { return nil }
        return first.first(where: { !$0.isEmpty }).map(decodeHTMLEntities)
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        captures(pattern: pattern, in: text).first?.first
    }

    private static func captures(
        pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]
    ) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, options: [], range: range).map { match in
            (1..<match.numberOfRanges).map { index in
                let captureRange = match.range(at: index)
                guard captureRange.location != NSNotFound else { return "" }
                return nsText.substring(with: captureRange)
            }
        }
    }

    private static func replaceMatches(
        pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators],
        transform: ([String]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return text }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        var output = text

        for match in matches.reversed() {
            let captures = (1..<match.numberOfRanges).map { index in
                let captureRange = match.range(at: index)
                guard captureRange.location != NSNotFound else { return "" }
                return nsText.substring(with: captureRange)
            }
            let replacement = transform(captures)
            if let range = Range(match.range, in: output) {
                output.replaceSubrange(range, with: replacement)
            }
        }

        return output
    }

    private static func removeMatches(pattern: String, in text: String) -> String {
        replaceMatches(pattern: pattern, in: text) { _ in "" }
    }

    private static func fencedCodeBlock(fromHTML html: String) -> String {
        let withoutCodeWrapper = html
            .replacingOccurrences(of: #"(?i)</?code\b[^>]*>"#, with: "", options: .regularExpression)
        let text = stripHTMLTags(withoutCodeWrapper)
            .trimmingCharacters(in: .newlines)
        return fencedCodeBlock(fromPlainText: text)
    }

    private static func fencedCodeBlock(fromPlainText text: String) -> String {
        let fence = codeFence(for: text)
        return "\(fence)\n\(text.trimmingCharacters(in: .newlines))\n\(fence)"
    }

    private static func inlineCodeMarkdown(_ text: String) -> String {
        let cleaned = decodeHTMLEntities(text)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return inlineCodeMarkdownContent(cleaned)
    }

    private static func inlineCodeMarkdownFromHTML(_ html: String) -> String {
        let cleaned = stripHTMLTags(html)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return inlineCodeMarkdownContent(cleaned)
    }

    private static func inlineCodeMarkdownContent(_ cleaned: String) -> String {
        guard !cleaned.isEmpty else { return "" }

        let fence = inlineCodeFence(for: cleaned)
        let needsPadding = cleaned.hasPrefix("`") || cleaned.hasSuffix("`")
        let content = needsPadding ? " \(cleaned) " : cleaned
        return "\(fence)\(content)\(fence)"
    }

    private static func codeFence(for text: String) -> String {
        let longestRun = longestBacktickRun(in: text)
        return String(repeating: "`", count: max(3, longestRun + 1))
    }

    private static func inlineCodeFence(for text: String) -> String {
        String(repeating: "`", count: longestBacktickRun(in: text) + 1)
    }

    private static func longestBacktickRun(in text: String) -> Int {
        var longest = 0
        var current = 0
        for character in text {
            if character == "`" {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    private static func stripHTMLTags(_ html: String) -> String {
        replaceMatches(pattern: "<br\\s*/?>", in: html) { _ in "\n" }
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    private static func listLineMarkdown(from text: String) -> String? {
        let trimmed = cleanInlineText(text)
        guard !trimmed.isEmpty else { return nil }

        let bulletMarkers = ["- ", "* ", "• ", "◦ ", "▪ ", "‣ "]
        for marker in bulletMarkers where trimmed.hasPrefix(marker) {
            return "- \(cleanInlineText(String(trimmed.dropFirst(marker.count))))"
        }

        if let numbered = firstCapture(pattern: "^(\\d+\\.\\s+.+)$", in: trimmed) {
            return numbered
        }

        let parenthesizedNumber = captures(pattern: "^(\\d+)\\)\\s+(.+)$", in: trimmed)
        if let match = parenthesizedNumber.first, match.count == 2 {
            return "\(match[0]). \(match[1])"
        }

        return nil
    }

    private static func joinBlocks(_ blocks: [String]) -> String {
        var output = ""
        var previousWasListLine = false

        for block in blocks {
            let currentIsListLine = isListMarkdownLine(block)
            if output.isEmpty {
                output = block
            } else {
                output += previousWasListLine && currentIsListLine ? "\n\(block)" : "\n\n\(block)"
            }
            previousWasListLine = currentIsListLine
        }

        return output
    }

    private static func isListMarkdownLine(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- ") {
            return true
        }
        return firstCapture(pattern: "^(\\d+\\.\\s+)", in: trimmed) != nil
    }

    private static func cleanBlockMarkdown(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var output: [String] = []
        var blankCount = 0
        var isInCodeFence = false
        for line in lines {
            let isFenceLine = line.trimmingCharacters(in: .whitespaces).hasPrefix("```")
            let normalizedLine = isInCodeFence && !isFenceLine ? line : line.trimmingCharacters(in: .whitespaces)

            if isFenceLine {
                blankCount = 0
                output.append(normalizedLine)
                isInCodeFence.toggle()
                continue
            }

            if normalizedLine.isEmpty {
                blankCount += 1
                if blankCount <= 1, !output.isEmpty {
                    output.append("")
                }
            } else {
                blankCount = 0
                output.append(normalizedLine)
            }
        }

        return output.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanInlineText(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(
            of: "[ \\t\\r\\f]+",
            with: " ",
            options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func escapeInlineText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    private static func escapeLinkLabel(_ text: String) -> String {
        text
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    private static func escapeTableCell(_ text: String) -> String {
        cleanInlineText(text)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        var output = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")

        output = replaceMatches(pattern: "&#(\\d+);", in: output) { captures in
            guard let value = UInt32(captures[0]), let scalar = UnicodeScalar(value) else { return "" }
            return String(Character(scalar))
        }
        output = replaceMatches(pattern: "&#x([0-9a-fA-F]+);", in: output) { captures in
            guard let value = UInt32(captures[0], radix: 16), let scalar = UnicodeScalar(value) else { return "" }
            return String(Character(scalar))
        }

        return output
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
