# Reviewer guide

For the native speaker checking a course's lessons. You do not need a developer account, Xcode or any
programming tools: only a computer with Chrome.

> **Status (2026-10-09).** The Tamil course's first five lessons are reviewed. Telugu lessons do not exist yet;
> this guide describes how their review will work once Level 1 is drafted. Steps marked *planned* depend on
> work in `plan.md` that is not built yet.

## What you are checking

Every phrase was drafted by an AI and is labelled "Unreviewed draft" in the app until you mark it reviewed.
Marking a phrase reviewed means you vouch for it: **a native speaker would really say this, to this person, in
everyday speech.** For each phrase, check:

- **The answer** is natural spoken language, not the written or textbook form.
- **The register** matches the prompt: casual for a friend, respectful for an elder or a stranger.
- **The accepted spellings** are other ways people would write the same answer in Latin letters.
- **The wrong options** are real sentences that mean something else. A wrong option that is also a correct
  answer must be changed.
- **The word-by-word gloss** matches the answer.
- **The spelling in the language's own script** matches the answer (*planned*: new lessons carry this field).

Change anything that is wrong. If you would say it differently, write what you would say. Your corrections
are also collected into style notes so that the next level is drafted better.

## One-time setup

1. Go to `https://github.com/darshan-r27/blt.ai`, choose **Code**, then **Download ZIP**, and unzip it.
2. Open `tools/content-editor/index.html` in Chrome (double-click it). It works offline and uploads nothing.

## Reviewing

1. In the editor click **Open content folder...** and choose your language's lesson folder inside the unzipped
   download (*planned*: `content/telugu` or `content/tamil`; today all lessons are in `content`). Allow read
   and write when Chrome asks.
2. The editor opens at the first phrase that is not yet reviewed and shows how many are done.
3. Read the phrase, fix anything that is wrong, and click **Mark reviewed**. **Previous** and **Next** only
   move; they change nothing.
4. The checklist beside each phrase shows any rule it breaks. A phrase with a problem cannot ship, so clear
   the checklist before marking it reviewed.
5. Click **Save changes** when you stop. You can close the editor and carry on later: progress is simply how
   many phrases are marked reviewed in the files.

Full details of the editor are in [`tools/content-editor/README.md`](../tools/content-editor/README.md).

## Sending your review back

1. When a level is done, send the lesson files you changed (the `.json` files in the folder you opened) to the
   owner. AirDrop works.
2. The owner looks at every change and adds the files to the project.

## Getting the new lessons on a phone

Lessons can be updated on a phone without rebuilding the app:

1. AirDrop the lesson files to the phone and choose **Save to Files**.
2. In blt.ai open **Settings**, tap **Import lessons** and choose the files.
3. The app checks every file. If all pass, they take effect at once and progress is kept. If any file fails,
   nothing changes and the app says so.

A phrase you have marked reviewed loses its "Unreviewed draft" label in the app. When every phrase in a course
is reviewed, Settings says the lessons were checked by a native speaker.
