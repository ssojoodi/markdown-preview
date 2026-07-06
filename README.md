# Markdown Preview

Markdown Preview is a macOS Quick Look preview extension for Markdown files.

After installing and enabling the app, select a Markdown file in Finder and press `Space` to see a rendered preview.

## What It Supports

- Headings (`#` through `######`)
- Paragraphs
- Unordered and ordered lists
- Blockquotes
- Tables
- Fenced code blocks (```)
- Mermaid diagrams in fenced `mermaid` code blocks
- Inline code, emphasis, strong emphasis, strikethrough
- Links
- Local image references

Markdown Preview uses a lightweight built-in renderer. It is not a full CommonMark or GitHub Flavored Markdown implementation.

## Requirements

- macOS 13.0 or newer
- Full Xcode app, not only Command Line Tools

## Project Layout

- `App/`: host macOS app used to install and contain the extension
- `Extension/`: Quick Look preview extension implementation
- `Brand/`: source SVG brand assets
- `Config/`: shared and local signing configuration
- `MarkdownPreview.xcodeproj/`: Xcode project with the app and extension targets

## Signing

This must be set up once in Xcode.

For local compile/run checks without an Apple Developer certificate, use the ad-hoc local build target:

```bash
make buildlocal
```

## Build And Run

Open `MarkdownPreview.xcodeproj` in Xcode, select the `MarkdownPreview` scheme, and run it.

You can also build from Terminal:

```bash
make build
```

To regenerate brand PNGs and app icon images from SVG sources:

```bash
make assets
```

## Package A DMG

Create a Release DMG with a drag-to-Applications installer window:

```bash
make package
```

The generated disk image is written to `.build/Dist/MarkdownPreview.dmg`.

## Release Outside The App Store

Create a Developer ID signed, notarized, and stapled Release DMG:

```bash
xcrun notarytool store-credentials "sojoodi-macapp-notary" \
  --team-id "YOURTEAMID" \
  --apple-id "YOUR_APPLE_ID" \
  --password "APP_SPECIFIC_PASSWORD"

make release
```

`make release` reads `DEVELOPMENT_TEAM` from ignored `Config/LocalSigning.xcconfig` by default. You can override release settings without editing files:

```bash
make release \
  DEVELOPER_ID_TEAM=YOURTEAMID \
  DEVELOPER_ID_IDENTITY="Developer ID Application" \
  NOTARY_PROFILE="sojoodi-macapp-notary"
```

The generated notarized disk image is written to `.build/Dist/MarkdownPreview.dmg`.

## Install And Enable

Install the built app:

```bash
make install
```

Launch Markdown Preview and use the setup screen to open `System Settings`.
Then enable the extension:

`General` -> `Login Items & Extensions` -> `Quick Look` -> `Markdown Preview`

Then select a `.md` or `.markdown` file in Finder and press `Space`.

To uninstall the app and disable its Quick Look extension:

```bash
make uninstall
```

## Refresh Quick Look

If Finder still shows plain text, refresh Quick Look:

```bash
make refresh
```

## Registered UTTypes

- `com.sojoodi.markdown`
- `public.markdown`
- `net.daringfireball.markdown`
- `net.multimarkdown.text`

## License

Markdown Preview is released under the MIT License. See [LICENSE](LICENSE).
