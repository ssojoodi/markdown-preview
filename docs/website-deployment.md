# Markdown Preview Website

The `web-page/` folder contains the static site for
<https://sojoodi.com/apps/MarkdownPreview/>. It includes the download page,
release notes, shared CSS, app icon, and preview image. No build step is needed.

## Prepare a Release

1. Run `make release`. After signing, notarization, stapling, and verification
   succeed, it copies the DMG to `web-page/MarkdownPreview.dmg`. The previous
   website DMG is backed up in `docs/dmg-backups/` with a UTC timestamp and a
   process ID to distinguish releases made in the same second.
2. Install and test `web-page/MarkdownPreview.dmg` before uploading it.
3. Update `web-page/release-notes.html` with the version and changes in that
   artifact. Do not describe changes that have not shipped in the download.
4. Open `web-page/index.html` and `web-page/release-notes.html` in a browser.
   Check both pages, their images, navigation, and download links.

The website DMG and backups are ignored by Git. A fresh checkout will not
contain a DMG until you run `make release`. A build copy also remains at
`.build/Dist/MarkdownPreview.dmg`. `make clean` preserves the website download
and backups. This step prepares local website files; it does not upload them.

## Deploy

Upload these files together into the web server's `/apps/MarkdownPreview/`
directory, preserving their names and capitalization:

- `index.html`
- `release-notes.html`
- `styles.css`
- `app-icon.png`
- `preview.jpg`
- `MarkdownPreview.dmg`

Upload the contents of `web-page/`, not an additional `web-page` directory.
Do not upload `.gitignore`. All local assets and page links are relative, so
the site can also be opened directly from disk for review.

After uploading, check both public pages and download the DMG through a browser.
Compare its SHA-256 hash with the tested local artifact:

```sh
shasum -a 256 web-page/MarkdownPreview.dmg
```

Keep the tested DMG unchanged when publishing it.
