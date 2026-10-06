# Content editor

A single offline HTML file for reviewing and editing `content/*.json`. No network, no dependencies, nothing is uploaded: it runs entirely in your browser.

**Use it**
1. Open `tools/content-editor/index.html` in Chrome or Edge (double-click it, or `open tools/content-editor/index.html`).
2. Click **Open content folder…** and pick the repo's `content` folder (allow read and write when asked).
3. **Review every item in order:** the editor opens at the first item you haven't checked yet and shows a bar at the top ("Item 37 of 100 · Scenario 2 of 5"). Use **← Back** / **Next →** to move one item at a time across all five scenarios, **✓ Looks right · Next** to mark an item checked as you move on, or **Mark reviewed · Next** to also set its status to `reviewed` (only if you are happy to vouch for it). Keyboard: **Alt+→** next, **Alt+←** back, **Alt+Shift+→** checked and next. Your checks are remembered in the browser, so you can close the page and resume; **Reset checks** starts over. With **Auto-save when moving on** ticked (Chrome/Edge folder mode) each edited file is written as you go.
   You can still jump to any item from the list on the left, or search and filter it. Edit the prompt, the correct answer, the wrong options, the accepted spellings and the word-by-word gloss. A live preview shows how the question looks and a checklist shows any problem.
4. Click **Save changes**. Files are written in place; review the diff with `git diff content/`.

Safari and Firefox cannot write into folders: use **Open files…**, and saving downloads the edited files to move into `content/`.

**Checks** (the same rules as the app's loader, `docs/MVP_PLAN.md` section 2): four distinct options; the correct answer is in the accepted spellings and no wrong option is; casual and respectful items need the other-register version and two wrong options, neutral items need three; 3 to 6 accepted spellings; every gloss word appears in the correct answer; romanised Tamil only (no Tamil script).

**Review sheet:** **Export review sheet (CSV)** produces a spreadsheet with a blank "reviewer verdict" and "correction" column for a native speaker.

After editing, run `scripts/test.sh package` (the content-conformance test loads every file with the real loader), then commit.
