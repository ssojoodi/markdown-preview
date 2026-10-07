# Manual Release Checks

Use disposable Markdown files. Run these checks against the packaged app before distributing it.

## Opening Documents

1. Quit the app, then open a Markdown file from Finder. The app must launch without crashing and show the document window in front.
2. Put another app in front, then open another Markdown file from Finder. The document window must come forward with the requested file.
3. Minimize the document window, then open a Markdown file from Finder. The window must restore and come forward.
4. Switch between the app and Finder several times. Focus changes must not crash the app.
5. Edit a document, then open another file from Finder. Cancel the unsaved-changes prompt; the original document and edits must remain visible.

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
3. Enable the extension and click Save Sample. Choose Documents in the save panel. Finder must select the saved Welcome.md. Press Space and verify the formatted heading, table, and Mermaid diagram. Canceling the save panel must leave setup open without an error or a new file.
4. Return and click Complete Setup. Relaunch; setup must remain completed. Confirm that completing setup does not require revealing the sample first.
5. Reopen Quick Look setup from the advanced options gear. Confirm the sample can be revealed again without changing the open document or its edits. Only Close should appear at the bottom; clicking it or pressing Escape must return to the document.
6. On a fresh account, choose Close. The app must be usable, setup must return on the next launch, and the gear must let you return immediately.
7. Before confirming setup, open a Markdown file through Finder or create one with Command-N. This must allow using the app without permanently marking setup complete.
8. Preview one of your own Markdown files in Finder and open it in the app. Check local images and diagrams in both places.
9. After completing setup, install a build with a newer release version and launch the app directly. Setup must appear again. Complete setup and relaunch; it must stay completed for that version.
10. Reinstall the same release after completing setup. Completion should persist; the advanced toolbar gear must still reopen setup. Preferences saved by the older boolean-based setup flow must not suppress setup for the first versioned release.

## Printing and Preview Zoom

1. Open a document containing multiple pages of text, a table, long code lines,
   local images, and wide/tall Mermaid diagrams. Use File → Print and Command-P.
   Confirm the native print dialog appears and Save as PDF includes the entire
   rendered document, without toolbar controls or clipped columns/diagrams.
2. Repeat in light and dark appearance. Verify readable text and diagram labels,
   appropriate page breaks, and PDF output at normal scale at both 50% and 300%
   screen zoom. Cancel printing and verify the previous zoom and scroll position.
3. Print immediately after opening a diagram-heavy document. Diagrams must finish
   rendering first. Invalid diagrams and missing images must not hang printing;
   a preparation timeout must show an error and permit a later retry.
4. Edit a saved document and an untitled document. Print without saving; output
   must contain the current Markdown source. Cancel and confirm edits, selection,
   undo, and dirty state remain unchanged. Repeat with a printer when available.
5. Use all three zoom menu commands and Command-=, Command--, and Command-0.
   Verify Mermaid labels enlarge, enlarged content remains reachable by scrolling,
   50%/300% limits disable the corresponding command, and Original restores 100%.
6. Scroll down and zoom or expand/collapse the toolbar. The preview must not reload
   or jump to the top. Reload the file, open another file, and switch between edit
   and preview: retain the window's zoom. A new window must start at 100%.
7. With two document windows, verify commands apply only to the active window and
   each keeps its own zoom. Test commands with a toolbar button focused as well.
8. Print and zoom must be disabled on setup, welcome, load-error, and converter
   screens. Zoom must also be disabled while editing. Repeated Print commands
   must not open overlapping dialogs. Switching documents during print preparation
   must not print the previous document.
9. Verify Finder Quick Look still renders Markdown and Mermaid normally.
