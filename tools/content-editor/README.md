# Content editor

A single offline HTML file for reviewing and editing `content/*.json`. No network, no dependencies, nothing is uploaded: it runs entirely in your browser.

**Use it**
1. Open `tools/content-editor/index.html` in Chrome or Edge (double-click it, or `open tools/content-editor/index.html`).
2. Click **Open content folder…** and pick the repo's `content` folder (allow read and write when asked).
3. **Review every item in order:** the editor opens at the first item that is not yet `reviewed` and shows a bar at the top ("Item 37 of 100 · Scenario 2 of 5 · 36 of 100 reviewed"). **← Previous** and **Next →** only move one item at a time across all five scenarios; they change nothing. **Mark reviewed** sets the item's status to `reviewed` (only if you are happy to vouch for it) and moves to the next item. Keyboard: **Alt+→** next, **Alt+←** previous, **Alt+Shift+→** mark reviewed and go to the next item. Progress is simply how many items are `reviewed` in the files, so closing the page and reopening it resumes at the first item that is not. With **Auto-save when moving on** ticked (Chrome/Edge folder mode) each edited file is written as you go.
   You can still jump to any item from the list on the left, or search and filter it. Edit the prompt, the correct answer, the wrong options, the accepted spellings and the word-by-word gloss (drag the ⠿ handle, or use the ↑ ↓ buttons, to reorder the words; **Sort by answer order** puts them in the order they appear in the correct answer). A live preview shows how the question looks and a checklist shows any problem.
4. Click **Save changes**. Files are written in place; review the diff with `git diff content/`.

Safari and Firefox cannot write into folders: use **Open files…**, and saving downloads the edited files to move into `content/`.

**Checks** (the same rules as the app's loader, `docs/MVP_PLAN.md` section 2 and `docs/DECISIONS.md` 038 to 040): four distinct options; the correct answer is in the accepted spellings and no wrong option is; casual and respectful items need the other-register version and two wrong options, neutral items need three; 3 to 6 accepted spellings, none listed twice (ignoring case and spaces); every gloss word appears in the correct answer; romanised Tamil only (no Tamil script, except in the Tamil script box below).

**Duplicates:** across all loaded files, no two items may share a prompt and no two may share a correct answer. Capitals, spaces and punctuation are ignored, so "Where is it?" and "where is it" count as the same. The message names the other item. Inside one item the rule is narrower: accepted spellings are only compared ignoring case and outer spaces, so spellings that differ by a question mark or a hyphen are fine.

**Level (optional, per lesson):** three boxes at the top of each lesson: level number, level title, position in the level. Number and position are whole numbers, 1 or more; the title cannot be empty. Fill in all three or leave all three empty (an empty level is not written to the file; **Remove level** deletes an existing one). Every lesson with the same level number must use the same title; the editor flags it on every file involved, so open all the files together.

**Tamil script (optional, per item):** a box under "Correct answer" for the answer written in Tamil script, for generating audio later. If filled it needs at least one Tamil letter and no English letters. This is the only box where Tamil script is accepted; every other field still rejects it. The app does not show it yet.

Saving keeps everything else in the file as it was: unknown keys, key order, and files with neither new field are written exactly as before.

**Review sheet:** **Export review sheet (CSV)** produces a spreadsheet with a blank "reviewer verdict" and "correction" column for a native speaker.

After editing, run `scripts/test.sh package` (the content-conformance test loads every file with the real loader), then commit.
