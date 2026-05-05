# Markdown Preview

Markdown Preview is a macOS Quick Look preview extension for Markdown files.

After installing and enabling the app, select a Markdown file in Finder and press `Space` to see a rendered preview.

## What It Supports

- Headings (`#` through `######`)
- Paragraphs
- Unordered and ordered lists
- Blockquotes
- Fenced code blocks (```)
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

The shared project reads its Apple Development Team ID from `Config/Signing.xcconfig`, which optionally includes a gitignored local file.

1. Copy the example signing config:

```bash
cp Config/LocalSigning.example.xcconfig Config/LocalSigning.xcconfig
```

2. Edit `Config/LocalSigning.xcconfig` and set your real team ID:

```xcconfig
DEVELOPMENT_TEAM = YOURTEAMID
```

`Config/LocalSigning.xcconfig` is ignored by git and should not be committed.

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

## Install And Enable

Install the built app:

```bash
make install
```

If macOS asks, enable the extension in `System Settings`:

`Privacy & Security` -> `Extensions` -> `Quick Look` -> `Markdown Preview`

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
