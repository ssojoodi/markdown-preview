# Release Workflow

When preparing a branch for release:

1. Review the branch diff and commits against `main`.
2. Update `web-page/release-notes.html` before creating the pull request.
   Mark changes as Upcoming until the release version and downloadable DMG
   are confirmed. Preserve previous release entries.
3. Create a pull request against `main` with a concise title, a functional
   summary, and the validation performed.

Write release notes and PR messages around what users can do and what now
works. Describe the affected action and resulting behavior. Avoid leading
with refactoring, dead-code removal, technical debt, or implementation details.
Include technical details only when needed to explain a limitation, required
action, or testing result. Do not claim unverified benefits or completed tests.

Before distributing a release, run `make release` and test the resulting
`web-page/MarkdownPreview.dmg` using `Tests/manual-release-checks.md`.
An unsigned build or a dry run does not verify the full release workflow.
Follow `docs/website-deployment.md` to publish the tested artifact.
