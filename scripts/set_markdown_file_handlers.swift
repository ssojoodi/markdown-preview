import AppKit
import CoreServices
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 4 else {
    fputs("Usage: set_markdown_file_handlers.swift BUNDLE_ID APP_PATH CONTENT_TYPE...\n", stderr)
    exit(2)
}

let bundleID = arguments[1]
let installedAppPath = URL(fileURLWithPath: arguments[2]).standardizedFileURL.path
let contentTypes = Array(arguments.dropFirst(3))
let cfBundleID = NSString(string: bundleID) as CFString
let roles: [(name: String, mask: LSRolesMask)] = [
    ("all", .all),
    ("viewer", .viewer),
    ("editor", .editor)
]

for contentType in contentTypes {
    let cfContentType = NSString(string: contentType) as CFString

    for role in roles {
        let status = LSSetDefaultRoleHandlerForContentType(cfContentType, role.mask, cfBundleID)
        if status == noErr {
            print("Set \(contentType) \(role.name): \(bundleID)")
        } else {
            print("Could not set \(contentType) \(role.name): OSStatus \(status)")
        }
    }
}

let testFile = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("markdown-preview-file-handler-check.md")

do {
    try "# Handler Check\n".write(to: testFile, atomically: true, encoding: .utf8)
} catch {
    fputs("Could not create Markdown handler check file: \(error)\n", stderr)
    exit(2)
}

guard let defaultApp = NSWorkspace.shared.urlForApplication(toOpen: testFile) else {
    fputs("No default app resolved for .md files.\n", stderr)
    exit(3)
}

let defaultAppPath = defaultApp.standardizedFileURL.path
let defaultBundleID = Bundle(url: defaultApp)?.bundleIdentifier ?? "unknown"

print("Default app for .md: \(defaultAppPath)")
print("Default bundle ID: \(defaultBundleID)")

guard defaultAppPath == installedAppPath else {
    fputs("Expected default app to be \(installedAppPath), but got \(defaultAppPath).\n", stderr)
    exit(3)
}
