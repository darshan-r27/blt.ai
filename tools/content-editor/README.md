# Content editor

A single offline HTML file for reviewing and editing `content/*.json`. No network, no dependencies, nothing is uploaded: it runs entirely in your browser.

**Use it**
1. Open `tools/content-editor/index.html` in Chrome or Edge (double-click it, or `open tools/content-editor/index.html`).
2. Click **Open content folder…** and pick the repo's `content` folder (allow read and write when asked).
3. **Review every item in order:** the editor opens at the first item that is not yet `reviewed` and shows a bar at the top ("Item 37 of 100 · Scenario 2 of 5 · 36 of 100 reviewed"). **← Previous** and **Next →** only move one item at a time across all five scenarios; they change nothing. **Mark reviewed** sets the item's status to `reviewed` (only if you are happy to vouch for it) and moves to the next item. Keyboard: **Alt+→** next, **Alt+←** previous, **Alt+Shift+→** mark reviewed and go to the next item. Progress is simply how many items are `reviewed` in the files, so closing the page and reopening it resumes at the first item that is not. With **Auto-save when moving on** ticked (Chrome/Edge folder mode) each edited file is written as you go.
   You can still jump to any item from the list on the left, or search and filter it. Edit the prompt, the correct answer, the wrong options, the accepted spellings and the word-by-word gloss (drag the ⠿ handle, or use the ↑ ↓ buttons, to reorder the words; **Sort by answer order** puts them in the order they appear in the correct answer). A live preview shows how the question looks and a checklist shows any problem.
4. Click **Save changes**. Files are written in place; review the diff with `git diff content/`.

Safari and Firefox cannot write into folders: use **Open files…**, and saving downloads the edited files to move into `content/`.

**Checks** (the same rules as the app's loader, `docs/MVP_PLAN.md` section 2 and `docs/DECISIONS.md` 038 to 040): four distinct options; the correct answer is in the accepted spellings and no wrong option is; casual and respectful items need the other-register version and two wrong options, neutral items need three; 3 to 6 accepted spellings, none listed twice (ignoring case and spaces); every gloss word appears in the correct answer; romanised text only (no Tamil or Telugu script, except in the script box below).

**Duplicates:** across all loaded files **of the same language**, no two items may share a prompt and no two may share a correct answer. Capitals, spaces and punctuation are ignored, so "Where is it?" and "where is it" count as the same. A Tamil lesson and a Telugu lesson are separate courses, so they never count as duplicates of each other. The message names the other item. Inside one item the rule is narrower: accepted spellings are only compared ignoring case and outer spaces, so spellings that differ by a question mark or a hyphen are fine.

**Level (optional, per lesson):** three boxes at the top of each lesson: level number, level title, position in the level. Number and position are whole numbers, 1 or more; the title cannot be empty. Fill in all three or leave all three empty (an empty level is not written to the file; **Remove level** deletes an existing one). Every lesson of the same language with the same level number must use the same title (each language numbers its own levels); the editor flags it on every file involved, so open all the files together.

**Language (required, per lesson):** a Language box at the top of each lesson: Tamil or Telugu. The editor never guesses it: a file with no language, or an unknown one, shows an error on the lesson until you choose. It is written to the file right after `scenarioId`. The sidebar shows each file's language, and labels and messages use it.

**Script (optional, per item):** a box under "Correct answer" for the answer written in the lesson language's own script ("Tamil script" or "Telugu script"), for generating audio later. If filled it needs at least one letter of that language's script and no English letters. This is the only box where Tamil or Telugu script is accepted; every other field rejects both. The app does not show it yet. The key is `script`; a leftover `tamilScript` key from the earlier format is not read or changed, it is kept in the file as an unknown key.

**Gloss words:** the word-by-word gloss uses the key `word`. A lesson that still uses the old key `tamil` is shown as an error ("old format: this lesson was exported before the two-language change; re-export it or rename the key"). The editor never reads the old key as a stand-in.

**If you review Telugu:** the editor works the same way for Telugu lessons. Set the lesson's Language to Telugu if it is not already, and follow `docs/REVIEWER_GUIDE.md` for how to get the files, what "reviewed" means and how to send them back.

Saving keeps everything else in the file as it was: unknown keys and key order are kept, and a file you did not change is written exactly as it was read.

**Review sheet:** **Export review sheet (CSV)** produces a spreadsheet (with language and script columns) plus blank "reviewer verdict" and "correction" columns for a native speaker.

After editing, run `scripts/test.sh package` (the content-conformance test loads every file with the real loader), then commit.
