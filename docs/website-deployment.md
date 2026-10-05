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
- `app-icon-160.png`
- `favicon-32.png`
- `apple-touch-icon.png`
- `preview.jpg` (full-size screenshot link)
- `preview-800.webp`
- `preview-1600.webp`
- `social-preview.png` (1200 × 630 sharing card)
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

## Website-only updates

For changes to HTML, CSS, or images, upload the website files listed above
without replacing the tested DMG. A website update does not verify a new app
release. Publish new assets before the HTML that references them.

## Search and sharing checks

Submit these canonical URLs to the centrally managed sitemap:

- https://sojoodi.com/apps/MarkdownPreview/
- https://sojoodi.com/apps/MarkdownPreview/release-notes.html

Do not create or overwrite the main site's sitemap.xml or robots.txt from this
project. The index.html file uses the directory URL as its canonical URL.

After deployment, confirm both canonical URLs return HTTP 200 without a
noindex directive in HTML or X-Robots-Tag headers. Confirm the central robots.txt
allows crawling these paths. Check all new image URLs, particularly
https://sojoodi.com/apps/MarkdownPreview/social-preview.png, return HTTP 200
with the correct image content type. Verify the social card remains 1200 × 630.
Check share previews with the target platforms after publishing; cached cards
may need to be refreshed. Structured data intentionally omits prices, ratings,
and release versions that are not established by the website update.

## Website validation — October 4, 2026

- Checked both updated pages in headless Chrome at 320, 390, 768, and 1440 px.
  No horizontal overflow, broken images, or missing image alt attributes.
  Each page has one H1; both skip links receive keyboard focus and move focus
  to main content. Inspected mobile and desktop screenshots.
- axe-core 4.10.3 reported no violations for WCAG 2 A/AA, WCAG 2.1 AA, and
  best-practice rules at those sizes. This is an automated check, not a full
  assistive-technology audit. Analytics requests were blocked during local tests.
- Validated JSON-LD parsing, required social metadata, local asset links, and
  fragment targets. `git diff --check` passed.
- Both live canonical pages, the main website, apps catalog, existing screenshot,
  app icon, and DMG returned HTTP 200. Page responses had no X-Robots-Tag
  restriction; central robots.txt allows crawling. Local pages have no noindex.
- The 800 px WebP is about 36 KB and the 1600 px WebP about 87 KB, compared
  with the original 214 KB JPEG. Dimensions reserve image space, the hero image
  has high fetch priority, and the release screenshot is lazy loaded. System
  fonts and the existing asynchronous analytics script need no extra blocking
  dependencies. No field Core Web Vitals measurement was performed.
- Deployment is pending. The new social-preview.png URL currently returns 404.
  Upload the new assets with the updated HTML/CSS, then repeat public URL and
  platform sharing checks. The existing DMG was neither changed nor release-tested
  as part of this website update. Central sitemap and robots.txt were unchanged.
