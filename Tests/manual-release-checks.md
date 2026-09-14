# Manual Release Checks

Use disposable Markdown files. Run these checks against the packaged app before distributing it.

## Unsaved Edits

Repeat for an existing file and a new document with text:

1. Edit the document, then close the window using the red close button or Command-W. Choose Cancel; the window and edits must remain.
2. Close again and choose Save. For a new document, cancel the save panel; the window and edits must remain. Repeat and finish saving; reopen the file and verify its contents.
3. Edit again, close, and choose Discard. The file on disk must remain unchanged.
4. Repeat the Save, Discard, and Cancel paths with Command-Q. Cancel must leave the app running. A canceled save panel or a failed write must also cancel quitting.
5. Try saving to a location where writing fails; the error must be shown and the document must stay open with its edits.
6. Close and quit an unchanged document; neither action should prompt.
7. Confirm that creating, opening, and reloading documents still prompt for unsaved edits.
8. If multiple document windows are open, edit each and quit. Each dirty window must be checked; canceling any prompt must cancel quitting and preserve all remaining edits.

## Setup and First Preview

1. Use a fresh macOS user account, install the DMG into Applications, and launch the app.
2. Click Open System Settings and return without enabling the extension. Setup must remain visible, including after relaunching.
3. Enable the extension and click Show Sample in Finder. Finder must select Welcome.md. Press Space and verify the formatted heading, table, and Mermaid diagram.
4. Return and click The Preview Works. Relaunch; setup must remain completed.
5. Reopen Quick Look setup from the advanced options gear. Confirm the sample can be revealed again without changing the open document or its edits.
6. On a fresh account, choose Set Up Later. The app must be usable, setup must return on the next launch, and the gear must let you return immediately.
7. Before confirming setup, open a Markdown file through Finder or create one with Command-N. This must allow using the app without permanently marking setup complete.
8. Preview one of your own Markdown files in Finder and open it in the app. Check local images and diagrams in both places.
